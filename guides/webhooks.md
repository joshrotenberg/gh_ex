# Webhooks

gh_ex is a client, so it does not run a web server. What it gives you is the part
that is easy to get wrong: `GhEx.Webhooks.verify/3` checks the delivery signature
in constant time, and `GhEx.Webhooks.parse/1` decodes the payload. You supply the
HTTP endpoint from whatever web layer you already run. This guide builds a minimal
receiver with `Plug`.

## The one rule: verify the raw body

GitHub signs the HMAC-SHA256 of the **exact bytes** it sent, in the
`X-Hub-Signature-256` header (`sha256=<hex>`). You must verify against the raw,
unparsed body. If a JSON parser has already consumed the body, the bytes you
verify will not match and every delivery fails. So read the raw body *before* any
parser runs on that route.

The other headers you want:

  * `X-GitHub-Event` - the event name (`push`, `pull_request`, `ping`, ...).
  * `X-GitHub-Delivery` - a unique delivery id, useful for logging and dedup.

## A minimal `Plug.Router` receiver

This route reads the raw body itself, so no `Plug.Parsers` runs before it.

```elixir
defmodule MyApp.WebhookRouter do
  use Plug.Router

  plug :match
  plug :dispatch

  post "/webhooks/github" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    secret = System.fetch_env!("GITHUB_WEBHOOK_SECRET")

    with :ok <- GhEx.Webhooks.verify(body, header(conn, "x-hub-signature-256"), secret),
         {:ok, payload} <- GhEx.Webhooks.parse(body) do
      handle(header(conn, "x-github-event"), header(conn, "x-github-delivery"), payload)
      send_resp(conn, 202, "")
    else
      {:error, reason} -> send_resp(conn, 401, to_string(reason))
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp header(conn, name), do: conn |> Plug.Conn.get_req_header(name) |> List.first()

  # GitHub sends a `ping` when the webhook is created; acknowledge it.
  defp handle("ping", _delivery, _payload), do: :ok

  defp handle(event, delivery, payload) do
    # Dispatch on `event` and act on `payload`. See "Respond fast" below.
    IO.puts("#{event} (#{delivery}): #{inspect(Map.keys(payload))}")
  end
end
```

`verify/3` returns `:ok`, `{:error, :invalid_signature}`, or
`{:error, :missing_signature}` (the last when the header is absent or not a
`sha256=` value), so an unsigned or wrongly-signed request is rejected by the
`with`.

## Respond fast, then work

GitHub expects a response within about 10 seconds, delivers each event
at-least-once, and retries on any non-2xx. So do the smallest possible thing in
the request: verify, then hand the work off and return `202`. Do not run your
handler inline.

```elixir
defp handle(event, delivery, payload) do
  # enqueue durable work; key it by `delivery` so GitHub's retries dedup
  MyApp.Jobs.HandleEvent.new(%{event: event, delivery: delivery, payload: payload})
  |> Oban.insert()
end
```

A background job (Oban, or a supervised `Task`) gives you retries and durability
that the HTTP handler cannot, and keeps the response well under the timeout.

## Phoenix

If a global `Plug.Parsers` already parsed the body by the time your controller
runs, `read_body/1` returns `""`. Cache the raw body with a custom `:body_reader`
so both the parser and your verification can see it:

```elixir
# endpoint.ex
plug Plug.Parsers,
  parsers: [:urlencoded, :json],
  json_decoder: Jason,
  body_reader: {MyApp.CacheBodyReader, :read_body, []}

# cache_body_reader.ex
defmodule MyApp.CacheBodyReader do
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
  end
end
```

Then verify against `conn.assigns.raw_body` in the controller. To limit the cost,
scope the caching reader to the webhook path only.

## What gh_ex does and does not do

gh_ex owns `verify/3` and `parse/1` - the transport-agnostic pieces every
receiver needs. The endpoint, routing, and any background processing are your
application's, because they depend on your web stack and runtime. gh_ex does not
ship a Plug or a server, and it does not model per-event payload structs: payloads
come back as raw maps, and you read the fields you need.
