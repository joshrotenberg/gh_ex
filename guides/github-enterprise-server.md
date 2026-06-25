# GitHub Enterprise Server

Point a client at a GitHub Enterprise Server instance by overriding the base
URLs. The REST and GraphQL endpoints are configured separately:

```elixir
client =
  GhEx.new(
    auth: {:token, token},
    rest_url: "https://ghe.example.com/api/v3",
    graphql_url: "https://ghe.example.com/api/graphql"
  )
```

Everything else works the same: REST verbs, GraphQL queries, pagination, and the
App and installation credentials all use these URLs. A GitHub App on Enterprise
Server uses the same `{:app, issuer, pem}` and installation flow described in the
[Authentication](authentication.md) guide; the installation client inherits the
app client's URLs.
