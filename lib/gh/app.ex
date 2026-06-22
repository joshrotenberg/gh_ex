defmodule GH.App do
  @moduledoc """
  GitHub App authentication.

  An app authenticates as itself with a JWT (see `GH.JWT`), built a client at a
  time from `{:app, issuer, pem}` credentials:

      app = GH.new(auth: {:app, client_id, File.read!("app.pem")})

  To act as an installation, the app mints a short-lived installation access
  token (valid one hour) and uses that as an ordinary bearer credential. This is
  the stateless primitive: `installation_client/3` mints once and hands back a
  plain token-auth client. Transparent caching and refresh of that token across
  its one-hour life is a later, opt-in layer; for now the caller decides when to
  re-mint, and `installation_token/3` exposes the `expires_at` to make that
  decision.

      {:ok, inst, _expires_at} = GH.App.installation_client(app, installation_id)
      GH.REST.get(inst, "/installation/repositories")
  """

  alias GH.{Client, REST}

  @doc """
  Mints an installation access token, returning GitHub's full response body
  (`"token"`, `"expires_at"`, `"permissions"`, `"repository_selection"`, ...).

  `app` must be a client with `{:app, ...}` credentials. Pass `:json` to scope
  the token to specific `repositories` or `permissions`.
  """
  @spec installation_token(Client.t(), integer() | String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def installation_token(%Client{} = app, installation_id, opts \\ []) do
    body = Keyword.get(opts, :json, %{})

    case REST.post(app, "/app/installations/#{installation_id}/access_tokens", json: body) do
      {:ok, token_body, _meta} -> {:ok, token_body}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Mints an installation token and returns a token-auth `GH.Client` that acts as
  that installation, alongside the token's `expires_at` string.

  The returned client inherits the app client's URLs and `:req_options`, so
  GitHub Enterprise base URLs and any `Req.Test` plug carry over.
  """
  @spec installation_client(Client.t(), integer() | String.t(), keyword()) ::
          {:ok, Client.t(), String.t() | nil} | {:error, term()}
  def installation_client(%Client{} = app, installation_id, opts \\ []) do
    case installation_token(app, installation_id, opts) do
      {:ok, %{"token" => token} = body} ->
        {:ok, %{app | auth: {:token, token}}, body["expires_at"]}

      {:ok, body} ->
        {:error, {:unexpected_response, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
