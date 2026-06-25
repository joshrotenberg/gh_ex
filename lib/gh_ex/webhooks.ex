defmodule GhEx.Webhooks do
  @moduledoc """
  Helpers for receiving GitHub webhooks: verify the delivery signature and decode
  the payload.

  GitHub signs each delivery with an HMAC-SHA256 of the raw request body, keyed by
  the webhook secret, in the `X-Hub-Signature-256` header (`sha256=<hex>`). The
  event name is in `X-GitHub-Event`. Read the raw body and those headers from your
  web framework, then verify and parse:

      with :ok <- GhEx.Webhooks.verify(body, signature, secret),
           {:ok, payload} <- GhEx.Webhooks.parse(body) do
        handle(event_name, payload)
      end

  Payloads are returned as raw maps; dispatch on the event name and read the
  fields you need.
  """

  @doc """
  Verifies a delivery signature in constant time.

  `payload` is the raw request body, `signature` is the `X-Hub-Signature-256`
  header value (`"sha256=<hex>"`), and `secret` is the webhook secret. Returns
  `:ok`, `{:error, :invalid_signature}`, or `{:error, :missing_signature}` when
  the header is absent or not a `sha256=` value.
  """
  @spec verify(binary(), String.t() | nil, binary()) ::
          :ok | {:error, :invalid_signature | :missing_signature}
  def verify(payload, "sha256=" <> hex, secret)
      when is_binary(payload) and is_binary(secret) do
    expected = :crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower)

    if secure_compare(expected, hex), do: :ok, else: {:error, :invalid_signature}
  end

  def verify(_payload, _signature, _secret), do: {:error, :missing_signature}

  @doc """
  Decodes a webhook payload (the raw JSON body) into a map.
  """
  @spec parse(binary()) :: {:ok, map()} | {:error, term()}
  def parse(payload) when is_binary(payload), do: Jason.decode(payload)

  defp secure_compare(a, b) do
    byte_size(a) == byte_size(b) and :crypto.hash_equals(a, b)
  end
end
