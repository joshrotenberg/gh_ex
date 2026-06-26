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

    with {:ok, client} <- Auth.resolve(client) do
      client
      |> Request.build_graphql(body)
      |> Req.request()
      |> handle()
    end
  end

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
            {:ok, data, _meta} -> emit(get_in(data, path), nodes_key)
            {:error, reason} -> raise reason
          end
      end,
      fn _ -> :ok end
    )
  end

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
