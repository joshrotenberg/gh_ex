# Getting started

`gh_ex` is a Req-based client for the GitHub REST and GraphQL APIs. A small
generic core reaches every endpoint; typed convenience modules are added as
needed.

## Install

```elixir
def deps do
  [
    {:gh_ex, "~> 0.1.0"}
  ]
end
```

## Build a client

One client is used for both transports. The most common credential is a token
(a classic or fine-grained personal access token, or an OAuth token):

```elixir
client = GhEx.new(auth: {:token, System.fetch_env!("GITHUB_TOKEN")})
```

A client with no `:auth` makes unauthenticated, rate-limited requests. See the
[Authentication](authentication.md) guide for GitHub App and installation
credentials.

## A first REST call

`GhEx.REST` exposes `get/3`, `post/3`, `patch/3`, `put/3`, and `delete/3`. Every
call returns `{:ok, body, meta}` on a 2xx or `{:error, reason}` otherwise.

```elixir
{:ok, repo, meta} = GhEx.REST.get(client, "/repos/elixir-lang/elixir")
repo["full_name"]          #=> "elixir-lang/elixir"
meta.rate_limit.remaining  #=> 4999
```

`meta` is a `GhEx.REST.Meta` carrying the status, response headers, parsed
pagination links, and a rate-limit snapshot.

## A first GraphQL call

`GhEx.GraphQL.query/3` runs any query or mutation. Variables are a keyword list
or map.

```elixir
{:ok, data, _meta} =
  GhEx.GraphQL.query(
    client,
    "query($login: String!) { user(login: $login) { name } }",
    login: "joshrotenberg"
  )
```

## Convenience modules

For common resources there are thin wrappers that fill in the path, such as
`GhEx.Issues` and `GhEx.PullRequests`:

```elixir
GhEx.Issues.list(client, "elixir-lang", "elixir", params: [state: "open"])
GhEx.PullRequests.create(client, "o", "r", %{title: "Fix", head: "fix", base: "main"})
```

They return the same `{:ok, body, meta}` shape as `GhEx.REST`. See the
[Resource modules](resources.md) guide for the full set (repositories, contents,
releases, actions, search, checks, statuses, users, orgs, teams, gists).

## Next

- [Resource modules](resources.md)
- [Authentication](authentication.md)
- [Pagination](pagination.md)
- [Error handling](error-handling.md)
- [GitHub Enterprise Server](github-enterprise-server.md)
- [Testing](testing.md)
