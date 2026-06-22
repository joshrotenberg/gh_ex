# gh_ex

A modern, complete, well-documented, well-tested Elixir library for the GitHub APIs.

This is a spec, not a commitment. It exists to scope a short prototype sprint and to support an honest go/no-go decision afterward. Read the "Is it worth it" section before writing the second module.

## Thesis

A thin, Req-based core makes all of GitHub's REST and GraphQL APIs reachable on day one. Typed conveniences cover the hot paths. Auth and pagination plumbing, the parts nobody wants to hand-roll, are first-class. "Complete" comes from the generic core, not from a hand-written endpoint catalog. "Modern" means Req, `Req.Test`, current auth and headers, and both APIs behind one client.

The bet: the core is small and the value is high. The part most GitHub clients over-invest in (enumerating every endpoint) is the part this library deliberately under-builds, because that is the part that rots and is the reason existing clients fall behind.

## Naming

Package and repo: `gh_ex`. Open question for the sprint: public module namespace. Options are `GH` (short, ergonomic, slight collision risk in user code) or `GhEx` (unambiguous, slightly noisier). This spec uses `GH` in examples; decide for real at first release, not before.

## Design principles

1. Core over catalog. A great `get/post/patch/delete/graphql` covers 100% of the API forever, including endpoints GitHub has not shipped yet. Convenience wrappers are sugar, added by demand, never a coverage obligation.
2. Req-native, adapter-swappable. Built on Req, so retries, redirects, and decompression come for free, `Req.Test` powers testing, and users can supply their own Finch pool.
3. Auth is the product. The token case is trivial. The GitHub App case (JWT mint, installation token mint, cache, refresh) is where a real library earns its keep. First-class, not an afterthought.
4. Both APIs, one client, one auth path. REST and GraphQL share the same client struct and credentials.
5. Honest errors. Normalize REST status codes and GraphQL's 200-with-`errors` body into one result shape.
6. Docs and tests are scope, not chores. Every public function carries a doctest or a `Req.Test` example. The README teaches the core first and conveniences second.

## Architecture

```
GH.Client        # struct: auth, rest_url, graphql_url, req_options
GH.Auth          # {:token, t} | {:app, app_id, pem, ...} | {:installation, ...}; JWT mint, token cache
GH.Request       # build and run via Req; inject Accept, X-GitHub-Api-Version, Authorization: Bearer
GH.REST          # get/post/patch/put/delete -> {:ok, body, meta} | {:error, reason}
GH.GraphQL       # query/mutation; variables; errors-array handling
GH.Pagination    # REST Link-header stream and GraphQL cursor (pageInfo) stream, one API
GH.RateLimit     # parse REST headers and GraphQL cost block; optional backoff
GH.<Resource>    # OPTIONAL conveniences: Issues, PullRequests, Repos, Releases, ProjectsV2, ...
```

Everything above the optional resource modules is roughly 400 to 600 LOC. Resource modules are where line count grows, and the whole point is that you write only the ones you need.

## Target API shape

```elixir
client = GH.new(auth: {:token, System.fetch_env!("GITHUB_TOKEN")})

# generic REST, full coverage, auto-paginated
GH.REST.get(client, "/repos/edgurgel/tentacat/issues", params: [state: "open"])

# generic GraphQL, reaches Projects v2 and Discussions that REST cannot
GH.GraphQL.query(client, @projects_v2_query, org: "joshrotenberg", number: 1)

# optional convenience over the generic core
GH.Issues.list(client, "edgurgel", "tentacat", state: "open")

# GitHub App: mint and cache an installation token transparently
app = GH.new(auth: {:app, app_id, pem})
inst = GH.App.installation_client(app, installation_id)
GH.REST.get(inst, "/installation/repositories")
```

## What "complete" means here

- REST: every endpoint immediately, via `GH.REST.get(client, "/any/path", ...)` with auto-pagination. Conveniences for the top resources (issues, pulls, repos, releases, commits, contents, orgs, webhooks, search).
- GraphQL: every query and mutation via `GH.GraphQL.query/3`, including Projects v2 and Discussions, which have no REST equivalent. Optional helpers for common Projects v2 operations.
- Auth: classic PAT, fine-grained PAT, OAuth token, and GitHub App (JWT signing, installation token mint, cache, refresh). GitHub Enterprise Server via base-url override.

This is a more complete GitHub story than Tentacat has ever offered, in a fraction of the maintained surface, because completeness is delegated to the generic core rather than enumerated by hand.

## The hard parts (where the time actually goes)

| Area | Difficulty | Note |
|---|---|---|
| App JWT and installation token | Medium-high | RS256 signing, short-lived JWT, token cache with expiry. The real differentiator. |
| Unified pagination | Medium | Link headers and GraphQL cursors behind one `Stream`. REST half is well understood; cursor half is new. |
| GraphQL error and union ergonomics | Medium | 200-with-errors handling; `... on` unions are verbose to traverse. |
| Rate limit and abuse backoff | Low-medium | Headers are easy; secondary-limit backoff is fiddly. |
| Testing without the live API | Medium | `Req.Test` stubs plus recorded fixtures; decide the contract-test boundary. |
| Staying current | Ongoing | Mitigated by core-over-catalog: new endpoints need zero code. |

## Non-goals

Keep these out so the project does not spiral:

- No exhaustive endpoint enumeration.
- No codegen from the OpenAPI spec. It produces a large unidiomatic surface and becomes its own maintenance burden.
- No webhook server. Payload structs are maybe in scope later; receiving and verifying webhooks is a sibling concern, possibly a separate library.
- No CLI.
- No caching layer beyond the auth token cache.
- No GHES version-specific shims at launch.

## Conventions and dependencies

- Elixir target: current stable (`~> 1.17` or newer at scaffold time).
- Core deps: `req`, `jason` (or Req's default), `jose` or equivalent for RS256 JWT signing.
- Dev and test: `ex_doc`, `req` test mode, `excoveralls` optional.
- Headers sent on every request: `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`, `Authorization: Bearer <token>`, a `User-Agent`.
- Result shape: `{:ok, body, meta}` and `{:error, reason}` where `meta` carries status, headers, rate-limit, and next-page info.

## Milestones

- M1, one weekend: `GH.Client` plus `GH.Auth` (token), REST get and post, Link-header pagination, normalized errors, README. Usable.
- M2, one weekend: GraphQL core plus cursor pagination plus a working Projects v2 example. The unlock nothing else in the ecosystem gives you.
- M3, one weekend: App auth (JWT plus installation token cache). The credibility feature.
- M4, ongoing: rate-limit handling, `Req.Test` harness, doctests, hex release, a handful of convenience resources.

A genuinely useful 0.1 (M1 through M3) is realistically about three focused weekends, because the catalog is not being written.

## Is it worth it

Decide this honestly after the prototype, not before.

For:

- Real, current gap: no Elixir library does GraphQL and Projects v2 plus modern App auth plus Req well. Not hypothetical; it is the exact wall that motivated this project.
- The design is small enough that it should not spiral. Core-over-catalog is the discipline that keeps a GitHub client from becoming a full-time job. Most prior art failed by not having it.
- Good-shaped side project: clear done-condition for 0.1, naturally library-shaped, interesting problems (auth, streaming) without an open-ended surface.

Against:

- A GitHub client is a maintenance commitment, not a build-once. Even with core-over-catalog, the auth and rate-limit logic track GitHub behavior. Abandoned-at-0.3 is worse than no library. Tentacat coasting is the cautionary tale.
- Adoption is hard. The incumbent has years of inertia. "Yet another GitHub client" is a crowded-sounding pitch even when justified.
- The pragmatic alternative (an existing REST wrapper plus a small amount of Req GraphQL in the app) covers immediate needs at near-zero cost. The library pays off only if it should exist for others, or it gets reused across several of your own projects.

Go/no-go gate after M2:

1. Does the unified pagination and GraphQL core feel genuinely nice, or merely fine? Merely fine means the Req-in-your-app path wins and you stop.
2. Are you willing to commit to App-auth correctness and roughly quarterly upkeep for two-plus years? No means do not publish; keep it internal.
3. Will you reuse it across two-plus of your own projects regardless of external adoption? Yes means it is worth it even with zero stars.

If two of the three are yes, it is a good side project. If the only yes is "it would be nice for the ecosystem," that is the weakest reason and historically the one that produces abandoned libraries.

## First sprint checklist

- [ ] `mix new gh_ex`, set up formatter, dialyzer optional, CI.
- [ ] `GH.Client` struct and `GH.new/1`.
- [ ] `GH.Auth` token path plus header injection.
- [ ] `GH.REST.get/post` over Req with `{:ok, body, meta}`.
- [ ] Link-header auto-pagination as a `Stream`.
- [ ] `GH.GraphQL.query/3` with variables and errors handling.
- [ ] Cursor pagination for GraphQL.
- [ ] One real Projects v2 example, end to end, against a live token.
- [ ] `Req.Test` harness and the first doctests.
- [ ] README that teaches the core first.
