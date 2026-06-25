defmodule GhEx.App do
  @moduledoc """
  GitHub App authentication.

  An app authenticates as itself with a JWT (see `GhEx.JWT`), built a client at a
  time from `{:app, issuer, pem}` credentials:

      app = GhEx.new(auth: {:app, client_id, File.read!("app.pem")})

  To act as an installation, the app mints a short-lived installation access
  token (valid one hour) and uses it as an ordinary bearer credential. There are
  two ways to get there:

    * `installation/3` returns a client that resolves and caches the token
      transparently, refreshing before it expires. This is the usual choice; it
      needs a running `GhEx.TokenCache`.

          inst = GhEx.App.installation(app, installation_id, cache: GhEx.TokenCache.ETS)
          GhEx.REST.get(inst, "/installation/repositories")

    * `installation_client/3` is the stateless primitive: it mints once and hands
      back a plain token-auth client plus the `expires_at`, leaving the one-hour
      lifecycle to the caller.

          {:ok, inst, _expires_at} = GhEx.App.installation_client(app, installation_id)
          GhEx.REST.get(inst, "/installation/repositories")
  """

  alias GhEx.{Client, REST}

  @doc """
  Returns a client that authenticates as the installation, resolving its access
  token through `cache` on demand and refreshing transparently before expiry.

  Construction does no I/O; the token is minted on the first request made with
  the returned client. Requires a running `GhEx.TokenCache` (see
  `GhEx.TokenCache.ETS`).

  ## Options

    * `:cache` - required. A `GhEx.TokenCache` module, or a `{module, ref}` tuple
      naming a specific cache instance.
    * `:json` - scopes the minted token to specific `repositories`/`permissions`;
      different scopes cache under different keys.
  """
  @spec installation(Client.t(), integer() | String.t(), keyword()) :: Client.t()
  def installation(%Client{} = app, installation_id, opts) do
    cache = Keyword.fetch!(opts, :cache)

    spec = %{
      app: app,
      id: installation_id,
      cache: cache,
      token_opts: Keyword.take(opts, [:json])
    }

    %{app | auth: {:installation, spec}}
  end

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
  Mints an installation token and returns a token-auth `GhEx.Client` that acts as
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
