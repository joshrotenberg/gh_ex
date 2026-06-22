# Backlog

Work tracking for `gh_ex`. Milestones follow `SPEC.md`. Newest decisions and open
questions at the bottom.

## Done

### M1: REST core over Req
- [x] `mix new`, formatter, `.gitignore`
- [x] `GH.Client` struct + `GH.new/1`
- [x] `GH.Auth` token path + bearer header injection
- [x] `GH.Request.build/4` with required headers
- [x] `GH.REST.get/post/patch/put/delete` -> `{:ok, body, meta}` / `{:error, reason}`
- [x] `GH.Error` normalization of 4xx/5xx, also an exception
- [x] Link-header auto-pagination as a `Stream` (`GH.REST.stream/3`)
- [x] `GH.RateLimit` header snapshot in `meta`
- [x] `Req.Test` harness + first doctests (13 tests, 4 doctests, green)

## M1 loose ends (quick wins before or alongside M2)
- [ ] README that teaches the core first (currently the `mix new` stub)
- [ ] CI: GitHub Actions running `mix format --check-formatted` and `mix test`
      (consider `credo` and `dialyzer` as optional gates)

## M2 GraphQL core (the go/no-go milestone)
- [x] `GH.GraphQL.query/3` over Req: query string + variables (keyword or map), shares
      `GH.Client` + auth via `GH.Request.build_graphql/3`
- [x] Normalize 200-with-`errors` body into `GH.Error` (`from_graphql/2`, partial data
      preserved on `:body`)
- [x] Cursor pagination via `pageInfo` exposed as `GH.GraphQL.stream/4`, mirroring
      `GH.REST.stream/3` (caller gives `:path` to the connection; `:cursor_var`/`:nodes_key`
      configurable)
- [x] GraphQL rate-limit cost block surfaced on `GH.GraphQL.Meta.cost` (raw map, lossless;
      `:rate_limit` stays the header-based view for parity with REST)
- [x] `Req.Test` coverage: query, variables, errors-array, empty-errors, cost block,
      cursor paging, stream error (20 tests green, 4 doctests)
- [x] One real Projects v2 example end to end against a live token (verified in iex:
      `viewer.projectsV2` streamed a real project via `stream/4`; also confirmed 334-repo
      multi-page cursor walk and the `rateLimit` cost block populating `meta.cost`)
- [ ] After M2: run the SPEC go/no-go gate honestly before building M3

## M3: App auth (the credibility feature)
- [ ] Choose RS256 signer dependency (`jose` or equivalent); check via hexpm MCP
- [ ] `GH.Auth` `{:app, app_id, pem}`: mint short-lived JWT
- [ ] Installation token mint + cache with expiry + refresh
- [ ] `GH.App.installation_client/2` resolving to the same bearer shape at request time
- [ ] Tests for JWT claims, cache hit/expiry/refresh

## M4: ongoing
- [ ] Secondary-limit / abuse backoff (automatic)
- [ ] Convenience resources by demand (Issues, Repos, PullRequests, Releases, ...)
- [ ] Expand doctests; consider `excoveralls`
- [ ] Hex release (0.1)

## Open decisions
- [ ] Public namespace: `GH` (ergonomic) vs `GhEx` (unambiguous). Decide at first release.
- [ ] Contract-test boundary: `Req.Test` stubs vs recorded fixtures for live endpoints.
- [ ] README rewrite happens before hex release regardless of when it lands above.
