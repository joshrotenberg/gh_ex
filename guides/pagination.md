# Pagination

Both transports expose pagination as a lazy `Stream`, so you page through large
collections without holding them in memory.

## REST

`GhEx.REST.stream/3` follows the `Link: rel="next"` header until GitHub stops
sending one. The first page's `:params` are applied once; later pages use the
exact `next` URL GitHub returns.

```elixir
client
|> GhEx.REST.stream("/repos/elixir-lang/elixir/issues", params: [state: "all", per_page: 100])
|> Stream.map(& &1["number"])
|> Enum.take(250)
```

A failed page raises `GhEx.Error` (a stream cannot return an `:error` tuple).

To drive pagination yourself, parse the header with `GhEx.Pagination.links/1`:

```elixir
{:ok, _body, meta} = GhEx.REST.get(client, "/repos/o/r/issues")
meta.links["next"]  #=> "https://api.github.com/repositories/1234/issues?page=2"
```

### Pacing against the rate limit

A long crawl can drain the primary rate limit and start firing into an empty
bucket. `GhEx.RateLimit.retry/2` recovers from that reactively (it waits out a
`403`/`429`), but you can also pace *proactively*: pause before the next request
once a response shows the bucket is nearly empty.

The library never sleeps on your behalf, so `stream/3` does not pace itself.
Instead, `GhEx.RateLimit.delay_until_reset/2` reads the `meta.rate_limit`
snapshot you already have and returns the milliseconds to wait (`0` when there is
headroom). You own the `Process.sleep`, in your own manual-pagination loop:

```elixir
Stream.unfold(:start, fn
  :halt ->
    nil

  cursor ->
    url = if cursor == :start, do: "/repos/o/r/issues?state=all&per_page=100", else: cursor
    {:ok, body, meta} = GhEx.REST.get(client, url)

    case GhEx.RateLimit.delay_until_reset(meta.rate_limit, floor: 50, buffer_ms: 1_000) do
      0 -> :ok
      ms -> Process.sleep(ms)
    end

    case meta.links["next"] do
      nil -> {body, :halt}
      next -> {body, {:next, next}}
    end
end)
|> Enum.flat_map(& &1)
```

This guards the *next* call from the snapshot you thread in; it does not protect
the first call (no prior snapshot), and a single snapshot is a partial view when
several processes share one token. Keep `retry/2` wired in as the backstop.

## GraphQL

`GhEx.GraphQL.stream/4` walks a connection's `pageInfo` cursor. The query takes a
cursor variable wired into `after:` and must select
`pageInfo { hasNextPage endCursor }`. Tell `stream/4` where the connection lives
with `:path`:

```elixir
query = ~s|
  query($org: String!, $cursor: String) {
    organization(login: $org) {
      projectsV2(first: 100, after: $cursor) {
        nodes { number title }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
|

client
|> GhEx.GraphQL.stream(query, [org: "joshrotenberg"], path: ["organization", "projectsV2"])
|> Enum.to_list()
```

Options: `:cursor_var` (the variable wired into `after:`, default `"cursor"`)
and `:nodes_key` (the field holding the page's items, default `"nodes"`).
