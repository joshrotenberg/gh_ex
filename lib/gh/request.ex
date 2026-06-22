defmodule GH.Request do
  @moduledoc """
  Builds the `Req` request shared by every API call.

  Injects the headers GitHub expects on every request (`Accept`,
  `X-GitHub-Api-Version`, `User-Agent`) and the `Authorization` bearer token
  resolved from the client's `GH.Auth` credential. Client `:req_options` and
  per-call options are merged last, so callers can override anything, including
  installing a `Req.Test` plug in tests.
  """

  alias GH.{Auth, Client}

  @accept "application/vnd.github+json"
  @api_version "2022-11-28"
  @user_agent "gh_ex/#{Mix.Project.config()[:version]}"

  @doc """
  Builds a `Req.Request` for `method` against `path` (relative to the client's
  REST base URL, or an absolute URL).
  """
  @spec build(Client.t(), atom(), String.t(), keyword()) :: Req.Request.t()
  def build(%Client{} = client, method, path, opts \\ []) do
    [
      method: method,
      base_url: client.rest_url,
      url: path,
      auth: Auth.req_auth(client.auth),
      headers: base_headers()
    ]
    |> Req.new()
    |> Req.merge(client.req_options)
    |> Req.merge(opts)
  end

  defp base_headers do
    [
      {"accept", @accept},
      {"x-github-api-version", @api_version},
      {"user-agent", @user_agent}
    ]
  end
end
