defmodule GH.Auth do
  @moduledoc """
  Credential handling.

  Two credential forms resolve to a bearer token here:

    * `{:token, t}` covers classic PATs, fine-grained PATs, and OAuth tokens.
    * `{:app, issuer, pem}` authenticates as a GitHub App by minting a fresh,
      short-lived RS256 JWT per request (see `GH.JWT`).

  The `{:installation, ...}` form is reserved: an installation acts via a minted
  installation access token, which `GH.App.installation_client/3` resolves into
  an ordinary `{:token, t}` client. Transparent caching of that token is a later
  layer.
  """

  @typedoc """
  A credential. The token and app forms resolve to a bearer token; the
  installation form is reserved (resolve it via `GH.App.installation_client/3`).
  """
  @type t ::
          {:token, String.t()}
          | {:app, app_id :: String.t() | integer(), pem :: String.t()}
          | {:installation, installation_id :: integer(), term()}

  @doc """
  Resolves a credential to the `Req` `:auth` option.

  Returns `nil` for an unauthenticated client (valid for public, rate-limited
  reads).

  ## Examples

      iex> GH.Auth.req_auth({:token, "secret"})
      {:bearer, "secret"}

      iex> GH.Auth.req_auth(nil)
      nil
  """
  @spec req_auth(t() | nil) :: {:bearer, String.t()} | nil
  def req_auth({:token, token}) when is_binary(token), do: {:bearer, token}
  def req_auth({:app, issuer, pem}), do: {:bearer, GH.JWT.mint(issuer, pem)}
  def req_auth(nil), do: nil
end
