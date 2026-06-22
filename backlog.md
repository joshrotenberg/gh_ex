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

## Documentation (kept current as we build)
- [x] README teaching the core first (REST, GraphQL, auth, GHES, testing)
- [x] CHANGELOG (Keep a Changelog format, Unreleased section)
- [x] ex_doc organized: `main: readme`, extras, `groups_for_modules`; `mix docs` warning-free
- Discipline: update README auth section + CHANGELOG + add an Authentication guide
  as M3b lands; keep module docs written inline with the code.

## M1 loose end
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

Decision: OTP-native RS256 signing, no JOSE dependency (one well-understood
algorithm via `:public_key`/`:crypto`). `jose` stays an escape hatch if a real
PEM exposes an edge case. Built in two stages.

### M3a: stateless primitive (done)
- [x] `GH.JWT.mint/3`: OTP-native RS256 GitHub App JWT (iss/iat/exp, clock-skew
      backdating, sub-600s lifetime). Verified against real OTP crypto in tests.
- [x] `GH.Auth` `{:app, issuer, pem}` resolves to a fresh bearer JWT per request
- [x] `GH.App.installation_token/3` mints an installation token, returns the full
      body (token, expires_at, permissions, repository_selection); `:json` scopes it
- [x] `GH.App.installation_client/3` returns a token-auth client + expires_at,
      inheriting the app client's URLs and req_options
- [x] Tests: JWT claims + signature verify, numeric issuer, skew/lifetime,
      req_auth app path, token mint (success/scoped/error), client mint (28 green)
- [ ] Smoke test against a real GitHub App PEM when one is handy (offline crypto
      tests already pass; this just confirms GitHub accepts the JWT)

### M3b: transparent cache (to discuss before building)
- [ ] `GH.TokenCache` behaviour with a default ETS-backed impl (~bring-your-own,
      Nebulex/Redis pluggable), so installation tokens cache + refresh transparently
- [ ] Decide: lazy resolve in the request path vs explicit refresh; the library's
      first process; refresh slightly before expires_at
- [ ] Optionally cache the app JWT (cheap to re-mint, low priority)

## M4: ongoing
- [ ] Secondary-limit / abuse backoff (automatic)
- [ ] Convenience resources by demand (Issues, Repos, PullRequests, Releases, ...)
- [ ] Expand doctests; consider `excoveralls`
- [ ] Hex release (0.1)

## Open decisions
- [ ] Public namespace: `GH` (ergonomic) vs `GhEx` (unambiguous). Decide at first release.
- [ ] Contract-test boundary: `Req.Test` stubs vs recorded fixtures for live endpoints.
- [ ] README rewrite happens before hex release regardless of when it lands above.
