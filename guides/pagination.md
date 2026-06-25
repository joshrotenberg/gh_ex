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
