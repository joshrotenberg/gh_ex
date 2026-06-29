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

  ## Conditional requests

  Each successful response's `meta` carries the `:etag` and `:last_modified`
  headers. Store one and send it back to make the next request conditional:

      {:ok, body, meta} = GhEx.REST.get(client, "/repos/o/r/issues")

      case GhEx.REST.get(client, "/repos/o/r/issues",
             headers: [{"if-none-match", meta.etag}]) do
        {:ok, :not_modified, meta} -> # unchanged; reuse the cached body
        {:ok, body, meta} -> # changed; meta.etag is the new validator
      end

  A `304 Not Modified` comes back as `{:ok, :not_modified, meta}`, distinct from
  both a normal `{:ok, body, meta}` and an `{:error, _}`. GitHub does not charge a
  `304` against the primary rate limit, so polling with the stored validator is
  cheaper than refetching. Storing the body is the caller's job; this is opt-in
  ergonomics, not a response cache.

  ## Telemetry

  Every REST call (and each `stream/3` page) is wrapped in `:telemetry.span/3`,
  emitting:

    * `[:gh_ex, :request, :start]` - measurements `%{system_time, monotonic_time}`,
      metadata `%{method, path}`.
    * `[:gh_ex, :request, :stop]` - measurements `%{duration, monotonic_time}`,
      metadata `%{method, path, result}` plus, on success, `status` and the
      `rate_limit` snapshot, or, on a normalized API/transport failure,
      `error` (the `{:error, reason}` is reported here, not as `:exception`).
    * `[:gh_ex, :request, :exception]` - emitted only if the call raises
      unexpectedly; measurements `%{duration, monotonic_time}`, metadata
      `%{method, path, kind, reason, stacktrace}`.

  Read `rate_limit.remaining` off the `:stop` metadata to wire rate-limit
  headroom into a metrics pipeline.
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

  `per_page` defaults to `100` for the first page when the caller does not set
  it, so a stream pages at GitHub's maximum rather than its default of `30`,
  cutting request count and rate-limit burn for large collections. Subsequent
  pages follow the `next` URL verbatim, which already carries the page size.

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
    opts = default_per_page(opts)

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

  # Streams have no upside to a smaller page, so default the first page to
  # GitHub's maximum of 100 when the caller has not set `per_page`. Only the
  # first page needs it; later pages follow the `next` URL, which already
  # carries the page size. `:params` may be a keyword list or a map (see
  # GhEx.Search), so honor an existing `per_page` under either key form.
  defp default_per_page(opts) do
    Keyword.update(opts, :params, [per_page: 100], &put_per_page/1)
  end

  defp put_per_page(params) when is_list(params) do
    if Keyword.has_key?(params, :per_page),
      do: params,
      else: Keyword.put(params, :per_page, 100)
  end

  defp put_per_page(params) when is_map(params) do
    if Map.has_key?(params, :per_page) or Map.has_key?(params, "per_page"),
      do: params,
      else: Map.put(params, :per_page, 100)
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

  # Every verb function and `stream/3` page funnels through here, so this is the
  # single REST choke point to instrument. `:telemetry.span/3` emits
  # `[:gh_ex, :request, :start | :stop | :exception]`; `:stop` carries the
  # duration plus the resolved status and rate-limit snapshot, and `:exception`
  # fires only on an unexpected raise (a normalized API/transport error comes
  # back as `{:error, _}` and is reported on `:stop`). The result tuple is
  # returned unchanged, so the `{:ok, body, meta} | {:error, reason}` shape holds.
  defp request(client, method, path, opts) do
    start_metadata = %{method: method, path: path}

    :telemetry.span([:gh_ex, :request], start_metadata, fn ->
      result =
        with {:ok, client} <- Auth.resolve(client) do
          client
          |> Request.build(method, path, opts)
          |> Req.request()
          |> handle()
        end

      {result, Map.merge(start_metadata, stop_metadata(result))}
    end)
  end

  defp stop_metadata({:ok, _body, meta}),
    do: %{result: :ok, status: meta.status, rate_limit: meta.rate_limit}

  defp stop_metadata({:error, reason}), do: %{result: :error, error: reason}

  defp handle({:ok, %Req.Response{status: status} = resp}) when status in 200..299 do
    {:ok, resp.body, meta(resp)}
  end

  # A `304 Not Modified` answers a conditional request (`If-None-Match` /
  # `If-Modified-Since`): the resource is unchanged, so GitHub sends no body and,
  # importantly, does not charge it against the primary rate limit. Return a
  # distinct `:not_modified` rather than the contradictory "HTTP 304 error", so a
  # poller can tell "unchanged" from a real failure. `meta` still carries the
  # fresh `ETag`/`Last-Modified` to send on the next poll.
  defp handle({:ok, %Req.Response{status: 304} = resp}), do: {:ok, :not_modified, meta(resp)}

  defp handle({:ok, %Req.Response{} = resp}), do: {:error, Error.from_response(resp)}
  defp handle({:error, exception}), do: {:error, exception}

  defp meta(%Req.Response{} = resp) do
    %GhEx.REST.Meta{
      status: resp.status,
      headers: resp.headers,
      links: Pagination.links(resp),
      rate_limit: RateLimit.from_response(resp),
      etag: header_first(resp, "etag"),
      last_modified: header_first(resp, "last-modified")
    }
  end

  defp header_first(resp, name) do
    case Req.Response.get_header(resp, name) do
      [value | _] -> value
      [] -> nil
    end
  end
end
