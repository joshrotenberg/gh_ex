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

  @doc """
  Mints a signed GitHub App JWT.

  `issuer` is the app's client id or numeric app id. `pem` is the app private
  key in PEM form, exactly as GitHub provides it.

  ## Options

    * `:now` - the current unix time in seconds. Defaults to the system clock;
      pass it in tests for a deterministic token.
    * `:skew` - seconds to backdate `iat`. Defaults to `60`.
    * `:lifetime` - seconds from `iat` to `exp`. Defaults to `540`.
  """
  @spec mint(String.t() | integer(), String.t(), keyword()) :: String.t()
  def mint(issuer, pem, opts \\ []) do
    now = Keyword.get(opts, :now, System.system_time(:second))
    skew = Keyword.get(opts, :skew, 60)
    lifetime = Keyword.get(opts, :lifetime, 540)

    iat = now - skew

    header = %{"alg" => "RS256", "typ" => "JWT"}
    claims = %{"iat" => iat, "exp" => iat + lifetime, "iss" => to_string(issuer)}

    signing_input = encode(header) <> "." <> encode(claims)
    signature = :public_key.sign(signing_input, :sha256, private_key(pem))
    signing_input <> "." <> Base.url_encode64(signature, padding: false)
  end

  defp encode(map), do: map |> Jason.encode!() |> Base.url_encode64(padding: false)

  defp private_key(pem) do
    pem
    |> :public_key.pem_decode()
    |> hd()
    |> :public_key.pem_entry_decode()
  end
end
