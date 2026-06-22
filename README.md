# gh_ex

A modern, Req-based Elixir client for the GitHub REST and GraphQL APIs.

The design is *core over catalog*: a small generic core reaches every GitHub
endpoint, today or later, and typed convenience modules are added by demand
rather than as a coverage obligation. Auth and pagination, the parts nobody wants
to hand-roll, are first class. See `SPEC.md` for the full rationale.

> Status: prototype. M1 (REST core), M2 (GraphQL core), and M3a (GitHub App JWT
> plus one-shot installation tokens) are implemented and tested. Transparent
> installation-token caching (M3b) is in progress. The public `GH` namespace is
> provisional and may become `GhEx` before the first release.

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
client = GH.new(auth: {:token, System.fetch_env!("GITHUB_TOKEN")})
```

### REST

`get/post/patch/put/delete` reach any path GitHub ships. Every call returns
`{:ok, body, meta}` on a 2xx or `{:error, reason}` otherwise, where `meta`
carries the status, headers, parsed pagination links, and a rate-limit snapshot.

```elixir
{:ok, repo, meta} = GH.REST.get(client, "/repos/elixir-lang/elixir")
repo["full_name"]        #=> "elixir-lang/elixir"
meta.rate_limit.remaining

GH.REST.post(client, "/repos/o/r/issues", json: %{title: "Bug", body: "..."})
```

`stream/3` follows the `Link: rel="next"` header into a lazy `Stream`, so you
page through large collections without holding them in memory:

```elixir
client
|> GH.REST.stream("/repos/elixir-lang/elixir/issues", params: [state: "all", per_page: 100])
|> Stream.map(& &1["number"])
|> Enum.take(250)
```

### GraphQL

`query/3` runs any query or mutation, including the corners REST cannot reach
such as Projects v2 and Discussions. Variables are a keyword list or map.

```elixir
{:ok, data, _meta} =
  GH.GraphQL.query(client, "query($login: String!) { user(login: $login) { name } }",
    login: "joshrotenberg")
```

GraphQL answers with HTTP 200 even on failure, so a response carrying an `errors`
array becomes `{:error, %GH.Error{}}` (the same error struct REST uses); any
partial `data` is preserved on the error.

`stream/4` walks a connection's `pageInfo` cursor into a lazy `Stream`, mirroring
the REST streamer. The query accepts a cursor variable wired into `after:` and
selects `pageInfo { hasNextPage endCursor }`; you tell `stream/4` where the
connection lives with `:path`:

```elixir
client
|> GH.GraphQL.stream(
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

## Authentication

`GH.new/1` accepts these credential forms:

```elixir
# personal access token (classic or fine-grained) or OAuth token
GH.new(auth: {:token, token})

# GitHub App: authenticates as the app with a short-lived RS256 JWT,
# minted via OTP crypto with no JOSE dependency
app = GH.new(auth: {:app, client_id_or_app_id, File.read!("app-private-key.pem")})
```

To act as an installation, mint an installation access token (valid one hour):

```elixir
# a token-auth client scoped to the installation, plus its expiry
{:ok, inst, _expires_at} = GH.App.installation_client(app, installation_id)
GH.REST.get(inst, "/installation/repositories")

# or the raw token body, optionally scoped to repositories/permissions
{:ok, body} = GH.App.installation_token(app, installation_id, json: %{repositories: ["gh_ex"]})
```

Today the caller owns the one-hour token lifecycle. Transparent caching and
refresh behind a `GH.TokenCache` behaviour is the M3b work in progress.

## GitHub Enterprise Server

Override the base URLs:

```elixir
GH.new(
  auth: {:token, token},
  rest_url: "https://ghe.example.com/api/v3",
  graphql_url: "https://ghe.example.com/api/graphql"
)
```

## Testing

The client is Req-native, so `Req.Test` drives it. Install a plug through
`:req_options` and stub responses, with no live API:

```elixir
client = GH.new(req_options: [plug: {Req.Test, MyStub}])
```

## Documentation

```
mix docs
```

## License

MIT.
