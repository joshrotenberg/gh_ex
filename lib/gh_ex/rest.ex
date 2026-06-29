defmodule GhEx.REST do
  @moduledoc """
  Generic REST access. Any GitHub REST path is reachable through `get/3`,
  `post/3`, `patch/3`, `put/3`, and `delete/3`.

  Every call returns `{:ok, body, meta}` on a 2xx or `{:error, reason}` otherwise,
  where `reason` is a `GhEx.Error` for an API error response or a `Req` exception for
  a transport failure. `meta` is a `GhEx.REST.Meta` struct carrying the status,
  response headers, parsed pagination links, and rate-limit snapshot.

  ## Options

  Per-call options are passed through to `Req`, so the useful ones are:

    * `:params` - query string parameters, e.g. `params: [state: "open", per_page: 100]`
    * `:json` - a body to JSON-encode for `post`/`patch`/`put`

  ## Examples

      GhEx.REST.get(client, "/repos/elixir-lang/elixir")
      GhEx.REST.get(client, "/repos/o/r/issues", params: [state: "open"])
      GhEx.REST.post(client, "/repos/o/r/issues", json: %{title: "Bug", body: "..."})
  """

  alias GhEx.{Auth, Client, Error, Pagination, RateLimit, Request}

  @type meta :: GhEx.REST.Meta.t()
  @type result :: {:ok, term(), meta()} | {:error, Error.t() | Exception.t()}

  @doc "Issues a `GET`."
  @spec get(Client.t(), String.t(), keyword()) :: result()
  def get(client, path, opts \\ []), do: request(client, :get, path, opts)

  @doc "Issues a `POST`."
  @spec post(Client.t(), String.t(), keyword()) :: result()
  def post(client, path, opts \\ []), do: request(client, :post, path, opts)

  @doc "Issues a `PATCH`."
  @spec patch(Client.t(), String.t(), keyword()) :: result()
  def patch(client, path, opts \\ []), do: request(client, :patch, path, opts)

  @doc "Issues a `PUT`."
  @spec put(Client.t(), String.t(), keyword()) :: result()
  def put(client, path, opts \\ []), do: request(client, :put, path, opts)

  @doc "Issues a `DELETE`."
  @spec delete(Client.t(), String.t(), keyword()) :: result()
  def delete(client, path, opts \\ []), do: request(client, :delete, path, opts)

  @doc """
  Runs a request and returns the raw `Req.Response`, without normalizing it.

  Unlike the verb functions, a non-2xx response comes back as
  `{:ok, %Req.Response{}}` (inspect `resp.status` yourself) rather than
  `{:error, _}`. Useful when a `404` means "absent" rather than an error, or when
  you need the raw status, headers, or body, or custom decoding. Auth resolution
  can still fail, returning `{:error, reason}`. Compose with
  `GhEx.Pagination.links/1` and `GhEx.RateLimit.from_response/1` for links or a
  rate-limit snapshot.
  """
  @spec raw(Client.t(), atom(), String.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, term()}
  def raw(client, method, path, opts \\ []) do
    with {:ok, client} <- Auth.resolve(client) do
      client
      |> Request.build(method, path, opts)
      |> Req.request()
    end
  end

  @doc """
  Auto-paginates a list endpoint into a lazy `Stream` of individual items.

  Follows the `Link: rel="next"` header until GitHub stops handing one back.
  The first page's `:params` are applied once; subsequent pages use the exact
  `next` URL GitHub returns, so cursors are never double-applied. A failed page
  raises `GhEx.Error`.

  A `next` URL whose origin (scheme, host, port) differs from the client's
  `rest_url` is refused with `GhEx.Error` rather than followed, so the bearer is
  never re-applied to an unauthorized host. A non-default GitHub Enterprise
  `rest_url` paginates normally, since its pages stay on the same origin.

  ## Options

    * `:items` - the key under which an object-wrapped response holds its array,
      for the endpoints that return `%{"total_count" => _, "items" => [...]}`
      rather than a bare array (Search `"items"`, Actions runs `"workflow_runs"`,
      Checks `"check_runs"`, and so on). When set, each page's items are taken
      from `body[items]` and flattened. Omit it for plain-array endpoints, which
      paginate unchanged. Any other option is forwarded to `Req` for the first
      page.

      client
      |> GhEx.REST.stream("/repos/elixir-lang/elixir/issues", params: [state: "all", per_page: 100])
      |> Stream.map(& &1["number"])
      |> Enum.take(250)
  """
  @spec stream(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, path, opts \\ []) do
    {items_key, opts} = Keyword.pop(opts, :items)

    Stream.resource(
      fn -> {:first, path, opts} end,
      fn
        :halt ->
          {:halt, nil}

        {:first, path, opts} ->
          emit(request(client, :get, path, opts), items_key)

        {:next, url} ->
          unless same_origin?(url, client.rest_url) do
            raise %Error{
              message: "refused cross-host pagination URL: #{URI.parse(url).host}"
            }
          end

          emit(request(client, :get, url, []), items_key)
      end,
      fn _ -> :ok end
    )
  end

  # Guards against a malicious or misconfigured upstream handing back a
  # `Link: rel="next"` that points at a different host. Following it would
  # re-apply the bearer to a host the caller never authorized, leaking the
  # credential. Same-origin is scheme + host + port against `client.rest_url`,
  # so a legitimate non-default GHE base still paginates.
  defp same_origin?(url, base) do
    a = URI.parse(url)
    b = URI.parse(base)
    a.scheme == b.scheme and a.host == b.host and a.port == b.port
  end

  defp emit({:ok, body, meta}, nil) when is_list(body), do: paginate(body, meta)

  defp emit({:ok, body, meta}, items_key) when is_map(body) and is_binary(items_key) do
    case Map.fetch(body, items_key) do
      {:ok, items} when is_list(items) -> paginate(items, meta)
      _ -> {[body], :halt}
    end
  end

  defp emit({:ok, body, _meta}, _items_key), do: {[body], :halt}
  defp emit({:error, reason}, _items_key), do: raise(reason)

  defp paginate(items, meta) do
    case meta.links["next"] do
      nil -> {items, :halt}
      url -> {items, {:next, url}}
    end
  end

  defp request(client, method, path, opts) do
    with {:ok, client} <- Auth.resolve(client) do
      client
      |> Request.build(method, path, opts)
      |> Req.request()
      |> handle()
    end
  end

  defp handle({:ok, %Req.Response{status: status} = resp}) when status in 200..299 do
    {:ok, resp.body, meta(resp)}
  end

  defp handle({:ok, %Req.Response{} = resp}), do: {:error, Error.from_response(resp)}
  defp handle({:error, exception}), do: {:error, exception}

  defp meta(%Req.Response{} = resp) do
    %GhEx.REST.Meta{
      status: resp.status,
      headers: resp.headers,
      links: Pagination.links(resp),
      rate_limit: RateLimit.from_response(resp)
    }
  end
end
