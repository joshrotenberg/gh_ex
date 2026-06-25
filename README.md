# gh_ex

A Req-based Elixir client for the GitHub REST and GraphQL APIs.

A small generic core reaches every GitHub endpoint over both transports. Typed
convenience modules are added as needed rather than for full endpoint coverage.
See `SPEC.md` for the design rationale.

## Highlights

- **REST and GraphQL.** `GhEx.REST.get/post/patch/put/delete` reach any REST
  path; `GhEx.GraphQL.query/3` reaches queries and mutations REST has no
  equivalent for, including Projects v2 and Discussions.
- **GitHub App authentication.** Authenticate as an App with an OTP-native RS256
  JWT (no JOSE dependency), and as an installation with an access token that is
  minted, cached, and refreshed transparently.
- **Built on Req.** Test with `Req.Test` and no HTTP mocking; errors normalize to
  `GhEx.Error`; `meta` carries a rate-limit snapshot and parsed pagination links;
  both transports paginate as a lazy `Stream`.
- **Generic core, convenience by demand.** Every endpoint is reachable through
  the core. Typed modules such as `GhEx.Issues` and `GhEx.PullRequests` wrap the
  common paths and are added as they are needed.

> Status: pre-release (0.1). M1 (REST core), M2 (GraphQL core), and M3 (GitHub
> App auth: JWT, one-shot installation tokens, and transparent installation-token
> caching) are implemented and tested. The public namespace is `GhEx`.

## Installation

```elixir
def deps do
  [
    {:gh_ex, "~> 0.1.0"}
  ]
end
```

## The core

One client, used for both transports:

```elixir
client = GhEx.new(auth: {:token, System.fetch_env!("GITHUB_TOKEN")})
```

### REST

`get/post/patch/put/delete` reach any REST path. Every call returns
`{:ok, body, meta}` on a 2xx or `{:error, reason}` otherwise, where `meta`
carries the status, headers, parsed pagination links, and a rate-limit snapshot.

```elixir
{:ok, repo, meta} = GhEx.REST.get(client, "/repos/elixir-lang/elixir")
repo["full_name"]        #=> "elixir-lang/elixir"
meta.rate_limit.remaining

GhEx.REST.post(client, "/repos/o/r/issues", json: %{title: "Bug", body: "..."})
```

`stream/3` follows the `Link: rel="next"` header into a lazy `Stream`, so you
page through large collections without holding them in memory:

```elixir
client
|> GhEx.REST.stream("/repos/elixir-lang/elixir/issues", params: [state: "all", per_page: 100])
|> Stream.map(& &1["number"])
|> Enum.take(250)
```

### GraphQL

`query/3` runs any query or mutation, including operations REST has no equivalent
for, such as Projects v2 and Discussions. Variables are a keyword list or map.

```elixir
{:ok, data, _meta} =
  GhEx.GraphQL.query(client, "query($login: String!) { user(login: $login) { name } }",
    login: "joshrotenberg")
```

GraphQL answers with HTTP 200 even on failure, so a response carrying an `errors`
array becomes `{:error, %GhEx.Error{}}` (the same error struct REST uses); any
partial `data` is preserved on the error.

`stream/4` walks a connection's `pageInfo` cursor into a lazy `Stream`, mirroring
the REST streamer. The query takes a cursor variable wired into `after:` and
selects `pageInfo { hasNextPage endCursor }`; you tell `stream/4` where the
connection lives with `:path`:

```elixir
client
|> GhEx.GraphQL.stream(
  ~s|query($org: String!, $cursor: String) {
       organization(login: $org) {
         projectsV2(first: 100, after: $cursor) {
           nodes { number title }
           pageInfo { hasNextPage endCursor }
         }
       }
     }|,
  [org: "joshrotenberg"],
  path: ["organization", "projectsV2"]
)
|> Enum.to_list()
```

### Convenience modules

`GhEx.Issues` and `GhEx.PullRequests` wrap the common paths and return the same
shape as the core:

```elixir
GhEx.Issues.list(client, "elixir-lang", "elixir", params: [state: "open"])
GhEx.PullRequests.create(client, "o", "r", %{title: "Fix", head: "fix", base: "main"})
```

## Authentication

`GhEx.new/1` accepts these credential forms:

```elixir
# personal access token (classic or fine-grained) or OAuth token
GhEx.new(auth: {:token, token})

# GitHub App: authenticates as the app with a short-lived RS256 JWT,
# minted via OTP crypto with no JOSE dependency
app = GhEx.new(auth: {:app, client_id_or_app_id, File.read!("app-private-key.pem")})
```

To act as an installation, get a client that mints and caches the installation
access token (valid one hour) transparently, refreshing it before it expires.
This needs a running token cache; add the default ETS cache to your supervision
tree:

```elixir
children = [
  GhEx.TokenCache.ETS
  # ...
]
```

```elixir
inst = GhEx.App.installation(app, installation_id, cache: GhEx.TokenCache.ETS)
GhEx.REST.get(inst, "/installation/repositories")
```

The cache is a behaviour: back it with your own module (Nebulex, Redis, ...) to
share tokens across a cluster, without `gh_ex` depending on any cache library.

If you would rather own the token lifecycle yourself, the stateless primitives
mint a single token and hand it back:

```elixir
# a token-auth client scoped to the installation, plus its expiry
{:ok, inst, _expires_at} = GhEx.App.installation_client(app, installation_id)

# or the raw token body, optionally scoped to repositories/permissions
{:ok, body} = GhEx.App.installation_token(app, installation_id, json: %{repositories: ["gh_ex"]})
```

See the [Authentication guide](guides/authentication.md) for the full flow.

## GitHub Enterprise Server

Override the base URLs:

```elixir
GhEx.new(
  auth: {:token, token},
  rest_url: "https://ghe.example.com/api/v3",
  graphql_url: "https://ghe.example.com/api/graphql"
)
```

## Testing

The client is Req-native, so `Req.Test` drives it. Install a plug through
`:req_options` and stub responses, with no live API:

```elixir
client = GhEx.new(req_options: [plug: {Req.Test, MyStub}])
```

See the [Testing guide](guides/testing.md) for asserting requests and stubbing
App and installation auth.

## Documentation

Run `mix docs`, or start with the [getting-started guide](guides/getting-started.md).
Guides cover [authentication](guides/authentication.md),
[pagination](guides/pagination.md), [error handling](guides/error-handling.md),
[GitHub Enterprise Server](guides/github-enterprise-server.md), and
[testing](guides/testing.md).

## License

MIT.
