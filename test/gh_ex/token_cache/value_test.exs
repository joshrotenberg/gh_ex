defmodule GhEx.TokenCache.ValueTest do
  use ExUnit.Case, async: true

  alias GhEx.TokenCache.Value

  test "the module is documented, so the public GhEx.TokenCache.value type names a documented struct" do
    assert {:docs_v1, _anno, :elixir, _format, %{"en" => moduledoc}, _meta, _docs} =
             Code.fetch_docs(Value)

    assert moduledoc =~ "redacting"
  end

  test "redacts :token from Inspect while still matching a plain token/expires_at map" do
    value = %Value{token: "ghs_secret", expires_at: ~U[2030-01-01 00:00:00Z]}

    refute inspect(value) =~ "ghs_secret"
    assert inspect(value) =~ "GhEx.TokenCache.Value"
    assert %{token: "ghs_secret", expires_at: %DateTime{}} = value
  end
end
