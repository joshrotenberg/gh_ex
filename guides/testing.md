# Testing

`gh_ex` is Req-native, so `Req.Test` drives it with no live API. Install a plug
through `:req_options` and stub responses per test.

## A stubbed request

```elixir
test "fetches a repo" do
  Req.Test.stub(MyApp.Stub, fn conn ->
    assert conn.request_path == "/repos/o/r"
    Req.Test.json(conn, %{"full_name" => "o/r"})
  end)

  client = GhEx.new(req_options: [plug: {Req.Test, MyApp.Stub}])

  assert {:ok, %{"full_name" => "o/r"}, _meta} = GhEx.REST.get(client, "/repos/o/r")
end
```

The stub receives a `Plug.Conn`, so you can assert on the method, path, query
string, headers, and body, and build any response.

## Asserting the request

```elixir
Req.Test.stub(MyApp.Stub, fn conn ->
  assert conn.method == "POST"
  {:ok, raw, conn} = Plug.Conn.read_body(conn)
  assert Jason.decode!(raw) == %{"title" => "Bug"}
  conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"number" => 1})
end)
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
