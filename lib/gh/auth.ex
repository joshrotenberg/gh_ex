defmodule GH.Auth do
  @moduledoc """
  Credential handling.

  M1 supports the token case, which covers classic PATs, fine-grained PATs, and
  OAuth tokens. All of them authenticate as `Authorization: Bearer <token>`.

  The GitHub App case (`{:app, ...}` and `{:installation, ...}`) is where a real
  library earns its keep: JWT minting and installation-token caching. Those land
  in M3 and resolve, at request time, to the same bearer-token shape returned here.
  """

  @typedoc """
  A credential. For now only the token form is implemented; the app and
  installation forms are reserved for M3.
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
  def req_auth(nil), do: nil
end
