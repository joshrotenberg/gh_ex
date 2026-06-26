defmodule GhExTest do
  use ExUnit.Case, async: true

  doctest GhEx
  doctest GhEx.Auth

  test "new/1 applies defaults" do
    client = GhEx.new()
    assert client.auth == nil
    assert client.rest_url == "https://api.github.com"
    assert client.graphql_url == "https://api.github.com/graphql"
    assert client.req_options == []
  end

  test "new/1 takes auth and overrides" do
    client = GhEx.new(auth: {:token, "t"}, rest_url: "https://ghe.example/api/v3")
    assert client.auth == {:token, "t"}
    assert client.rest_url == "https://ghe.example/api/v3"
  end

  test "inspect redacts the bearer token from a client" do
    dump = inspect(GhEx.new(auth: {:token, "ghp_supersecret"}))
    refute dump =~ "ghp_supersecret"
    refute dump =~ "auth:"
    assert dump =~ "GhEx.Client"
  end

  test "inspect redacts an App private key from a client" do
    pem =
      "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA-secret-material\n-----END RSA PRIVATE KEY-----"

    dump = inspect(GhEx.new(auth: {:app, "Iv1.app", pem}))
    refute dump =~ "secret-material"
    refute dump =~ "PRIVATE KEY"
  end
end
