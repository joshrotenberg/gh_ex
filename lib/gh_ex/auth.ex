defmodule GhEx.Auth do
  @moduledoc """
  Credential handling.

  Two credential forms resolve to a bearer token here:

    * `{:token, t}` covers classic PATs, fine-grained PATs, and OAuth tokens.
    * `{:app, issuer, pem}` authenticates as a GitHub App by minting a fresh,
      short-lived RS256 JWT per request (see `GhEx.JWT`).

  The `{:installation, spec}` form authenticates as an App installation. It
  carries the app client, installation id, and a `GhEx.TokenCache`; building it with
  `GhEx.App.installation/3` and resolving it with `resolve/1` mints and caches the
  installation access token transparently, refreshing before it expires.
  """

  @typedoc """
  A credential.

    * `{:token, t}` resolves directly to a bearer token.
    * `{:app, issuer, pem}` mints a short-lived App JWT per request.
    * `{:installation, spec}` resolves through a token cache; see
      `GhEx.App.installation/3`. The spec map carries `:app`, `:id`, `:cache`, and
      optional `:token_opts`.
  """
  @type t ::
          {:token, String.t()}
          | {:app, app_id :: String.t() | integer(), pem :: String.t()}
          | {:installation, spec :: map()}

  @doc """
  Resolves a credential to the `Req` `:auth` option.

  Returns `nil` for an unauthenticated client (valid for public, rate-limited
  reads).

  ## Examples

      iex> GhEx.Auth.req_auth({:token, "secret"})
      {:bearer, "secret"}

      iex> GhEx.Auth.req_auth(nil)
      nil
  """
  @spec req_auth(t() | nil) :: {:bearer, String.t()} | nil
  def req_auth({:token, token}) when is_binary(token), do: {:bearer, token}
  def req_auth({:app, issuer, pem}), do: {:bearer, GhEx.JWT.mint(issuer, pem)}
  def req_auth(nil), do: nil

  @doc """
  Resolves any credential the request path cannot handle purely.

  An `{:installation, spec}` credential is resolved to a concrete `{:token, t}`
  by minting (or reusing a cached) installation access token, which may perform a
  network round-trip and may fail. Every other credential passes through
  unchanged. Returns `{:ok, client}` with a request-ready credential, or
  `{:error, reason}` if minting failed.
  """
  @spec resolve(GhEx.Client.t()) :: {:ok, GhEx.Client.t()} | {:error, term()}
  def resolve(%GhEx.Client{auth: {:installation, spec}} = client) do
    case GhEx.Auth.Installation.token(spec) do
      {:ok, token} -> {:ok, %{client | auth: {:token, token}}}
      {:error, reason} -> {:error, reason}
    end
  end

  def resolve(%GhEx.Client{} = client), do: {:ok, client}
end
