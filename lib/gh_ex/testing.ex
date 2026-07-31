defmodule GhEx.Testing do
  @moduledoc """
  Helpers for testing gh_ex consumers with `Req.Test`.

  `client/1` installs a named `Req.Test` stub and disables retries so a stubbed
  transient failure returns immediately. The response builders cover common
  GitHub metadata, conditional requests, and rate-limit classifications.

  `Req.Test` uses Plug connections. Add Plug to the consuming application's
  test dependencies when using this module:

      {:plug, "~> 1.16", only: :test}
  """

  alias GhEx.Client

  @reset_epoch "4102444800"

  @type rate_limit_kind :: :retry_after | :primary | :secondary

  @doc """
  Builds a retry-disabled client that sends requests through a named
  `Req.Test` stub.

  ## Examples

      iex> client = GhEx.Testing.client(MyApp.GitHubStub)
      iex> client.req_options
      [plug: {Req.Test, MyApp.GitHubStub}, retry: false]
  """
  @spec client(term()) :: Client.t()
  def client(stub) do
    GhEx.new(req_options: [plug: {Req.Test, stub}, retry: false])
  end

  @doc """
  Sends a JSON response with a standard GitHub core rate-limit snapshot.

  Respects a response status already set on the connection, as
  `Req.Test.json/2` does.

  ## Examples

      iex> plug = fn conn -> GhEx.Testing.json(conn, %{ok: true}) end
      iex> response = Req.get!(url: "https://example.test", plug: plug, retry: false)
      iex> response.body
      %{"ok" => true}
      iex> response.headers["x-ratelimit-remaining"]
      ["4999"]
  """
  @spec json(term(), term()) :: term()
  def json(conn, body) do
    conn
    |> put_headers(standard_rate_limit_headers())
    |> json_response(body)
  end

  @doc """
  Sends an empty `304 Not Modified` response.

  ## Examples

      iex> plug = &GhEx.Testing.not_modified/1
      iex> response = Req.get!(url: "https://example.test", plug: plug, retry: false)
      iex> response.status
      304
  """
  @spec not_modified(term()) :: term()
  def not_modified(conn) do
    conn
    |> put_status(304)
    |> send_resp("")
  end

  @doc """
  Sends one of GitHub's rate-limit response shapes.

    * `:retry_after` sends a `429` with `retry-after: 1`.
    * `:primary` sends a `403` with an exhausted core bucket and reset time.
    * `:secondary` sends a body-only secondary-limit `403`.

  ## Examples

      iex> plug = fn conn -> GhEx.Testing.rate_limited(conn, :secondary) end
      iex> response = Req.get!(url: "https://example.test", plug: plug, retry: false)
      iex> response.status
      403
      iex> response.body["message"] =~ "secondary rate limit"
      true
  """
  @spec rate_limited(term(), rate_limit_kind()) :: term()
  def rate_limited(conn, :retry_after) do
    conn
    |> put_status(429)
    |> put_header("retry-after", "1")
    |> json_response(%{"message" => "API rate limit exceeded"})
  end

  def rate_limited(conn, :primary) do
    conn
    |> put_status(403)
    |> put_headers([
      {"x-ratelimit-limit", "5000"},
      {"x-ratelimit-remaining", "0"},
      {"x-ratelimit-used", "5000"},
      {"x-ratelimit-reset", @reset_epoch},
      {"x-ratelimit-resource", "core"}
    ])
    |> json_response(%{"message" => "API rate limit exceeded"})
  end

  def rate_limited(conn, :secondary) do
    conn
    |> put_status(403)
    |> json_response(%{
      "message" => "You have exceeded a secondary rate limit. Please wait."
    })
  end

  defp standard_rate_limit_headers do
    [
      {"x-ratelimit-limit", "5000"},
      {"x-ratelimit-remaining", "4999"},
      {"x-ratelimit-used", "1"},
      {"x-ratelimit-reset", @reset_epoch},
      {"x-ratelimit-resource", "core"}
    ]
  end

  defp put_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, conn -> put_header(conn, name, value) end)
  end

  # Plug is intentionally a test-only dependency. Dynamic dispatch keeps this
  # public helper module loadable in production builds that do not install it;
  # Req.Test provides the corresponding missing-Plug error if a response helper
  # is called without the documented test dependency.
  # credo:disable-for-next-line Credo.Check.Refactor.Apply
  defp put_header(conn, name, value), do: apply(Plug.Conn, :put_resp_header, [conn, name, value])
  # credo:disable-for-next-line Credo.Check.Refactor.Apply
  defp put_status(conn, status), do: apply(Plug.Conn, :put_status, [conn, status])
  # credo:disable-for-next-line Credo.Check.Refactor.Apply
  defp send_resp(conn, body), do: apply(Plug.Conn, :send_resp, [conn, conn.status, body])
  # credo:disable-for-next-line Credo.Check.Refactor.Apply
  defp json_response(conn, body), do: apply(Req.Test, :json, [conn, body])
end
