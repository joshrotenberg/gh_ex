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
  Auto-paginates a list endpoint into a lazy `Stream` of individual items.

  Follows the `Link: rel="next"` header until GitHub stops handing one back.
  The first page's `:params` are applied once; subsequent pages use the exact
  `next` URL GitHub returns, so cursors are never double-applied. A failed page
  raises `GhEx.Error`.

      client
      |> GhEx.REST.stream("/repos/elixir-lang/elixir/issues", params: [state: "all", per_page: 100])
      |> Stream.map(& &1["number"])
      |> Enum.take(250)
  """
  @spec stream(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, path, opts \\ []) do
    Stream.resource(
      fn -> {:first, path, opts} end,
      fn
        :halt ->
          {:halt, nil}

        {:first, path, opts} ->
          emit(request(client, :get, path, opts))

        {:next, url} ->
          emit(request(client, :get, url, []))
      end,
      fn _ -> :ok end
    )
  end

  defp emit({:ok, body, meta}) when is_list(body) do
    case meta.links["next"] do
      nil -> {body, :halt}
      url -> {body, {:next, url}}
    end
  end

  defp emit({:ok, body, _meta}), do: {[body], :halt}
  defp emit({:error, reason}), do: raise(reason)

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
