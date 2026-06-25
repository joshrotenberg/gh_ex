defmodule GhEx.WebhooksTest do
  use ExUnit.Case, async: true

  doctest GhEx.Webhooks

  @secret "s3cr3t"
  @payload ~s({"action":"opened","number":1})

  defp sign(payload, secret) do
    "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower))
  end

  describe "verify/3" do
    test "accepts a valid signature" do
      assert :ok = GhEx.Webhooks.verify(@payload, sign(@payload, @secret), @secret)
    end

    test "rejects a tampered payload" do
      sig = sign(@payload, @secret)
      assert {:error, :invalid_signature} = GhEx.Webhooks.verify(@payload <> "x", sig, @secret)
    end

    test "rejects a wrong secret" do
      assert {:error, :invalid_signature} =
               GhEx.Webhooks.verify(@payload, sign(@payload, "other"), @secret)
    end

    test "reports a missing or non-sha256 signature header" do
      assert {:error, :missing_signature} = GhEx.Webhooks.verify(@payload, nil, @secret)
      assert {:error, :missing_signature} = GhEx.Webhooks.verify(@payload, "sha1=abc", @secret)
    end
  end

  describe "parse/1" do
    test "decodes a JSON payload" do
      assert {:ok, %{"action" => "opened", "number" => 1}} = GhEx.Webhooks.parse(@payload)
    end

    test "errors on invalid JSON" do
      assert {:error, _} = GhEx.Webhooks.parse("{not json")
    end
  end
end
