defmodule GhEx.JWTTest do
  use ExUnit.Case, async: true

  setup_all do
    private = :public_key.generate_key({:rsa, 2048, 65_537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, private)])
    # RSAPrivateKey record: {:RSAPrivateKey, version, modulus, publicExponent, ...}
    public = {:RSAPublicKey, elem(private, 2), elem(private, 3)}
    %{pem: pem, public: public}
  end

  test "mints a verifiable RS256 JWT with GitHub App claims", %{pem: pem, public: public} do
    assert {:ok, jwt} = GhEx.JWT.mint("Iv1.client", pem, now: 1_000_000)
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

  test "sends a numeric issuer (App ID) as an integer", %{pem: pem} do
    for issuer <- [123_456, "123456"] do
      assert {:ok, jwt} = GhEx.JWT.mint(issuer, pem, now: 1_000_000)
      [_h, c64, _s] = String.split(jwt, ".")
      claims = c64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
      # GitHub rejects a string App ID with "'Issuer' claim ('iss') must be an Integer".
      assert claims["iss"] == 123_456
    end
  end

  test "honors :skew and :lifetime", %{pem: pem} do
    assert {:ok, jwt} = GhEx.JWT.mint("app", pem, now: 2_000_000, skew: 10, lifetime: 300)
    [_h, c64, _s] = String.split(jwt, ".")
    claims = c64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
    assert claims["iat"] == 2_000_000 - 10
    assert claims["exp"] == claims["iat"] + 300
  end

  test "rejects a :lifetime over GitHub's 600-second ceiling", %{pem: pem} do
    assert {:error, {:invalid_lifetime, 700}} = GhEx.JWT.mint("app", pem, lifetime: 700)
  end

  test "rejects a non-positive :lifetime that would mint an already-expired JWT", %{pem: pem} do
    assert {:error, {:invalid_lifetime, 0}} = GhEx.JWT.mint("app", pem, lifetime: 0)
    assert {:error, {:invalid_lifetime, -5}} = GhEx.JWT.mint("app", pem, lifetime: -5)
  end

  test "returns {:error, :invalid_pem} on a malformed PEM" do
    assert {:error, :invalid_pem} = GhEx.JWT.mint("app", "-----BEGIN nonsense-----")
  end

  test "GhEx.Auth.resolve mints an app credential into a token JWT", %{pem: pem} do
    client = GhEx.new(auth: {:app, "app", pem})
    assert {:ok, %GhEx.Client{auth: {:token, jwt}}} = GhEx.Auth.resolve(client)
    assert [_h, _c, _s] = String.split(jwt, ".")
  end

  test "a bad-PEM app client surfaces an error instead of crashing the request" do
    client = GhEx.new(auth: {:app, "app", "not a pem"})
    assert {:error, :invalid_pem} = GhEx.Auth.resolve(client)
    assert {:error, :invalid_pem} = GhEx.REST.get(client, "/user")
  end
end
