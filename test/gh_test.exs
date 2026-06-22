defmodule GHTest do
  use ExUnit.Case, async: true

  doctest GH
  doctest GH.Auth

  test "new/1 applies defaults" do
    client = GH.new()
    assert client.auth == nil
    assert client.rest_url == "https://api.github.com"
    assert client.graphql_url == "https://api.github.com/graphql"
    assert client.req_options == []
  end

  test "new/1 takes auth and overrides" do
    client = GH.new(auth: {:token, "t"}, rest_url: "https://ghe.example/api/v3")
    assert client.auth == {:token, "t"}
    assert client.rest_url == "https://ghe.example/api/v3"
  end
end
