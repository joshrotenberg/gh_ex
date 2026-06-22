defmodule GH.JWTTest do
  use ExUnit.Case, async: true

  setup_all do
    private = :public_key.generate_key({:rsa, 2048, 65_537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, private)])
    # RSAPrivateKey record: {:RSAPrivateKey, version, modulus, publicExponent, ...}
    public = {:RSAPublicKey, elem(private, 2), elem(private, 3)}
    %{pem: pem, public: public}
  end

  test "mints a verifiable RS256 JWT with GitHub App claims", %{pem: pem, public: public} do
    jwt = GH.JWT.mint("Iv1.client", pem, now: 1_000_000)
    [h64, c64, s64] = String.split(jwt, ".")

    header = h64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
    claims = c64 |> Base.url_decode64!(padding: false) |> Jason.decode!()

    assert header == %{"alg" => "RS256", "typ" => "JWT"}
    assert claims["iss"] == "Iv1.client"
    assert claims["iat"] == 1_000_000 - 60
    assert claims["exp"] == claims["iat"] + 540

    signature = Base.url_decode64!(s64, padding: false)
    assert :public_key.verify(h64 <> "." <> c64, :sha256, signature, public)
  end

  test "stringifies a numeric issuer", %{pem: pem} do
    jwt = GH.JWT.mint(123_456, pem, now: 1_000_000)
    [_h, c64, _s] = String.split(jwt, ".")
    claims = c64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
    assert claims["iss"] == "123456"
  end

  test "honors :skew and :lifetime", %{pem: pem} do
    jwt = GH.JWT.mint("app", pem, now: 2_000_000, skew: 10, lifetime: 300)
    [_h, c64, _s] = String.split(jwt, ".")
    claims = c64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
    assert claims["iat"] == 2_000_000 - 10
    assert claims["exp"] == claims["iat"] + 300
  end

  test "GH.Auth.req_auth resolves an app credential to a bearer JWT", %{pem: pem} do
    assert {:bearer, jwt} = GH.Auth.req_auth({:app, "app", pem})
    assert [_h, _c, _s] = String.split(jwt, ".")
  end
end
