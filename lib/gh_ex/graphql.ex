defmodule GhEx.GraphQL do
  @moduledoc """
  Generic GraphQL access. This is the whole GraphQL API: any query or mutation,
  including the corners REST cannot reach, such as Projects v2 and Discussions.

  `query/3` runs a single operation. `stream/4` walks a cursor-paginated
  connection into a lazy `Stream`, mirroring `GhEx.REST.stream/3` so both transports
  paginate through one mental model.

  ## Result shape

  `query/3` returns `{:ok, data, meta}` on success, where `data` is the contents of
  the GraphQL `data` field and `meta` is a `GhEx.GraphQL.Meta`. GraphQL answers with
  HTTP 200 even on failure, so a response carrying a non-empty `errors` array
  becomes `{:error, %GhEx.Error{}}`; any partial `data` is preserved on the error's
  `:body`. Transport failures return the `Req` exception.

  ## Variables

  Pass variables as a keyword list or map. Keys may be atoms or strings; both
  serialize to the matching `$name` in the query.

      GhEx.GraphQL.query(client, ~s|query($login: String!) {
        user(login: $login) { name }
      }|, login: "joshrotenberg")

  ## Pagination

  `stream/4` drives a connection's `pageInfo`. The query must accept a cursor
  variable (named `cursor` by default) wired into the connection's `after:`
  argument, and must select `pageInfo { hasNextPage endCursor }` alongside the
  nodes. Tell `stream/4` where the connection lives with `:path`:

      query = ~s|query($org: String!, $cursor: String) {
        organization(login: $org) {
          projectsV2(first: 100, after: $cursor) {
            nodes { id title }
            pageInfo { hasNextPage endCursor }
          }
        }
      }|

      client
      |> GhEx.GraphQL.stream(query, [org: "joshrotenberg"], path: ["organization", "projectsV2"])
      |> Stream.map(& &1["title"])
      |> Enum.to_list()

  A failed page raises `GhEx.Error`.

  ## Telemetry

  Every `query/3` call (and each `stream/4` page) is wrapped in
  `:telemetry.span/3`, emitting its own event family separate from REST so the
  two transports can be metered independently:

    * `[:gh_ex, :graphql, :start]` - measurements `%{system_time, monotonic_time}`,
      metadata `%{operation: :graphql}`.
    * `[:gh_ex, :graphql, :stop]` - measurements `%{duration, monotonic_time}`,
      metadata `%{operation, result}` plus, on success, `status`, the
      `rate_limit` snapshot, and the GraphQL `cost` (the `rateLimit` block when
      the query selects it), or, on a 200-with-errors/transport failure,
      `error`.
    * `[:gh_ex, :graphql, :exception]` - emitted only if the call raises
      unexpectedly; measurements `%{duration, monotonic_time}`, metadata
      `%{operation, kind, reason, stacktrace}`.
  """

  alias GhEx.{Auth, Client, Error, RateLimit, Request}

  @type meta :: GhEx.GraphQL.Meta.t()
  @type result :: {:ok, term(), meta()} | {:error, Error.t() | Exception.t()}

  @doc """
  Runs a single GraphQL `query` (or mutation) with optional `variables`.
  """
  @spec query(Client.t(), String.t(), keyword() | map()) :: result()
  def query(client, query, variables \\ []) do
    body = %{query: query, variables: Map.new(variables)}
    start_metadata = %{operation: :graphql}

    :telemetry.span([:gh_ex, :graphql], start_metadata, fn ->
      result =
        with {:ok, client} <- Auth.resolve(client) do
          client
          |> Request.build_graphql(body)
          |> Req.request()
          |> handle()
        end

      {result, Map.merge(start_metadata, stop_metadata(result))}
    end)
  end

  # GraphQL gets its own `[:gh_ex, :graphql, ...]` event family rather than
  # sharing `[:gh_ex, :request]`, so consumers can meter the two transports
  # separately and the `:stop` metadata can carry the GraphQL `cost` snapshot
  # that REST has no analogue for. `stream/4` pages through `query/3`, so it is
  # instrumented for free. The result tuple is returned unchanged.
  defp stop_metadata({:ok, _data, meta}),
    do: %{result: :ok, status: meta.status, rate_limit: meta.rate_limit, cost: meta.cost}

  defp stop_metadata({:error, reason}), do: %{result: :error, error: reason}

  @doc """
  Streams the nodes of a cursor-paginated connection.

  ## Options

    * `:path` - required. The list of keys from `data` down to the connection,
      e.g. `["organization", "projectsV2"]`.
    * `:cursor_var` - the variable name wired into `after:`. Defaults to `"cursor"`.
    * `:nodes_key` - the field holding the page's items. Defaults to `"nodes"`.
  """
  @spec stream(Client.t(), String.t(), keyword() | map(), keyword()) :: Enumerable.t()
  def stream(client, query, variables \\ [], opts) do
    path = Keyword.fetch!(opts, :path)
    cursor_var = Keyword.get(opts, :cursor_var, "cursor")
    nodes_key = Keyword.get(opts, :nodes_key, "nodes")
    base_vars = Map.new(variables)

    Stream.resource(
      fn -> {:cont, nil} end,
      fn
        :halt ->
          {:halt, nil}

        {:cont, cursor} ->
          vars = Map.put(base_vars, cursor_var, cursor)

          case query(client, query, vars) do
            {:ok, data, _meta} -> emit(dig(data, path), nodes_key)
            {:error, reason} -> raise reason
          end
      end,
      fn _ -> :ok end
    )
  end

  # Walks `path` like `get_in/2`, but a non-map intermediate (e.g. a list reached
  # by an over-specified `:path`) resolves to `nil` and halts the stream cleanly,
  # rather than letting Access raise a raw ArgumentError from inside the stream.
  defp dig(value, []), do: value
  defp dig(map, [key | rest]) when is_map(map), do: dig(Map.get(map, key), rest)
  defp dig(_value, _path), do: nil

  defp emit(nil, _nodes_key), do: {[], :halt}

  defp emit(connection, nodes_key) do
    nodes = Map.get(connection, nodes_key, [])
    page_info = Map.get(connection, "pageInfo", %{})

    case {page_info["hasNextPage"], page_info["endCursor"]} do
      {true, cursor} when is_binary(cursor) -> {nodes, {:cont, cursor}}
      _ -> {nodes, :halt}
    end
  end

  defp handle({:ok, %Req.Response{status: 200, body: body} = resp}) when is_map(body) do
    data = Map.get(body, "data")

    case Map.get(body, "errors") do
      errors when is_list(errors) and errors != [] -> {:error, Error.from_graphql(errors, data)}
      _ -> {:ok, data, meta(resp, data)}
    end
  end

  defp handle({:ok, %Req.Response{status: 200, body: body}}),
    do: {:error, Error.from_graphql_shape(body)}

  defp handle({:ok, %Req.Response{} = resp}), do: {:error, Error.from_response(resp)}
  defp handle({:error, exception}), do: {:error, exception}

  defp meta(%Req.Response{} = resp, data) do
    %GhEx.GraphQL.Meta{
      status: resp.status,
      headers: resp.headers,
      rate_limit: RateLimit.from_response(resp),
      cost: cost(data)
    }
  end

  defp cost(data) when is_map(data), do: Map.get(data, "rateLimit")
  defp cost(_data), do: nil
end
