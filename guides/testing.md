# Testing

`gh_ex` is Req-native, so `Req.Test` drives it with no live API. Add Plug to
your test dependencies, then use `GhEx.Testing.client/1` to install a named
stub with retries disabled:

```elixir
{:plug, "~> 1.16", only: :test}
```

## A stubbed request

```elixir
test "fetches a repo" do
  Req.Test.stub(MyApp.Stub, fn conn ->
    assert conn.request_path == "/repos/o/r"
    Req.Test.json(conn, %{"full_name" => "o/r"})
  end)

  client = GhEx.Testing.client(MyApp.Stub)

  assert {:ok, %{"full_name" => "o/r"}, _meta} = GhEx.REST.get(client, "/repos/o/r")
end
```

The stub receives a `Plug.Conn`, so you can assert on the method, path, query
string, headers, and body. `GhEx.Testing.json/2` adds a standard core
rate-limit snapshot to the response so assertions can include `meta`.

## Asserting the request

```elixir
Req.Test.stub(MyApp.Stub, fn conn ->
  assert conn.method == "POST"
  {:ok, raw, conn} = Plug.Conn.read_body(conn)
  assert Jason.decode!(raw) == %{"title" => "Bug"}
  conn |> Plug.Conn.put_status(201) |> GhEx.Testing.json(%{"number" => 1})
end)
```

Because the client sets `retry: false`, a stubbed `500` or other transient
failure returns immediately instead of following Req's production retry
schedule.

## Conditional and rate-limit responses

Use `GhEx.Testing.not_modified/1` for an ETag poll's `304` path. The
`GhEx.Testing.rate_limited/2` variants cover retry-after, exhausted primary
bucket, and body-only secondary rate limits:

```elixir
Req.Test.stub(MyApp.Stub, fn conn ->
  GhEx.Testing.rate_limited(conn, :secondary)
end)

assert {:error, %GhEx.Error{} = error} =
         GhEx.REST.get(GhEx.Testing.client(MyApp.Stub), "/repos/o/r")

assert GhEx.Error.classify(error) == :rate_limited
```

## Errors and pagination

Return a non-2xx status to exercise error handling, or a `Link` header to drive
`GhEx.REST.stream/3`:

```elixir
conn
|> Plug.Conn.put_resp_header("link", ~s(<#{next_url}>; rel="next"))
|> Req.Test.json([%{"n" => 1}])
```

## App and installation auth

Minting an installation token runs inside the cache GenServer, a different
process than the test. Allow it to use the stub with `Req.Test.allow/3`:

```elixir
cache_pid = start_supervised!({GhEx.TokenCache.ETS, name: MyApp.Cache})
Req.Test.allow(MyApp.Stub, self(), cache_pid)
```

Then the stub handles both the access-tokens POST (as the app) and the API call
(as the installation).
