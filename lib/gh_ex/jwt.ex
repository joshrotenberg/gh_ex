defmodule GhEx.JWT do
  @moduledoc """
  Mints the short-lived JWT a GitHub App presents to authenticate as itself.

  The token is signed RS256 (RSASSA-PKCS1-v1_5 over SHA-256) with the app's
  private key. That single, well-understood algorithm is handled by OTP's
  `:public_key` and `:crypto` directly, so no JOSE dependency is pulled in.

  GitHub's rules, encoded as the defaults here:

    * `iss` is the app's client id (preferred) or numeric app id.
    * `iat` is set `:skew` seconds in the past to tolerate clock drift between
      this machine and GitHub (default 60).
    * `exp` is `iat + :lifetime`, kept under GitHub's 10-minute ceiling
      (default 540 seconds, so the `exp - iat` span is well under 600).

  This is the credential used to mint installation tokens; see `GhEx.App`.
  """

  @max_lifetime 600

  @doc """
  Mints a signed GitHub App JWT.

  `issuer` is the app's client id or numeric app id. `pem` is the app private
  key in PEM form, exactly as GitHub provides it.

  Returns `{:ok, jwt}`, or `{:error, reason}` when the PEM cannot be decoded
  (`:invalid_pem`) or `:lifetime` is not in `1..#{@max_lifetime}`
  (`{:invalid_lifetime, lifetime}`); a non-positive lifetime would yield an
  already-expired token, and a longer one exceeds GitHub's ceiling.

  ## Options

    * `:now` - the current unix time in seconds. Defaults to the system clock;
      pass it in tests for a deterministic token.
    * `:skew` - seconds to backdate `iat`. Defaults to `60`.
    * `:lifetime` - seconds from `iat` to `exp`. Defaults to `540`. Must be in
      `1..#{@max_lifetime}`; a non-positive value mints an already-expired JWT
      and a larger one is rejected by GitHub.
  """
  @spec mint(String.t() | integer(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, :invalid_pem | {:invalid_lifetime, integer()}}
  def mint(issuer, pem, opts \\ []) do
    now = Keyword.get(opts, :now, System.system_time(:second))
    skew = Keyword.get(opts, :skew, 60)
    lifetime = Keyword.get(opts, :lifetime, 540)

    with :ok <- validate_lifetime(lifetime),
         {:ok, key} <- private_key(pem) do
      iat = now - skew

      header = %{"alg" => "RS256", "typ" => "JWT"}
      claims = %{"iat" => iat, "exp" => iat + lifetime, "iss" => issuer_claim(issuer)}

      signing_input = encode(header) <> "." <> encode(claims)
      signature = :public_key.sign(signing_input, :sha256, key)
      {:ok, signing_input <> "." <> Base.url_encode64(signature, padding: false)}
    end
  end

  defp encode(map), do: map |> Jason.encode!() |> Base.url_encode64(padding: false)

  # GitHub requires the App ID as a JSON integer; a Client ID stays a string.
  defp issuer_claim(issuer) when is_integer(issuer), do: issuer

  defp issuer_claim(issuer) when is_binary(issuer) do
    case Integer.parse(issuer) do
      {int, ""} -> int
      _ -> issuer
    end
  end

  defp validate_lifetime(lifetime) when lifetime > 0 and lifetime <= @max_lifetime, do: :ok
  defp validate_lifetime(lifetime), do: {:error, {:invalid_lifetime, lifetime}}

  defp private_key(pem) do
    case :public_key.pem_decode(pem) do
      [entry | _] -> {:ok, :public_key.pem_entry_decode(entry)}
      [] -> {:error, :invalid_pem}
    end
  end
end
