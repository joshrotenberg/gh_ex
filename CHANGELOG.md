# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow semantic versioning once it reaches a release.

## [Unreleased]

### Added

- REST core (`GhEx.REST`): `get/post/patch/put/delete` returning `{:ok, body, meta}`
  / `{:error, reason}`, and `stream/3` for `Link`-header auto-pagination.
- GraphQL core (`GhEx.GraphQL`): `query/3` with variable passing and 200-with-errors
  normalization into `GhEx.Error`, and `stream/4` for `pageInfo` cursor pagination.
- Client and request plumbing: `GhEx.new/1`, `GhEx.Client`, `GhEx.Request`, with the
  required GitHub headers and bearer auth injected on every call.
- Auth (`GhEx.Auth`): `{:token, t}` and `{:app, issuer, pem}` credential forms.
- GitHub App auth: `GhEx.JWT.mint/3` (OTP-native RS256, no JOSE dependency) and
  `GhEx.App.installation_token/3` / `installation_client/3` for one-shot
  installation access tokens.
- Transparent installation-token caching: `GhEx.App.installation/3` returns a
  client that mints, caches, and refreshes its token through a `GhEx.TokenCache`.
  `GhEx.TokenCache.ETS` is the default supervised cache (single-flight minting);
  the behaviour lets you plug in a clustered backend.
- Metadata and errors: `GhEx.REST.Meta`, `GhEx.GraphQL.Meta`, `GhEx.RateLimit`,
  `GhEx.Pagination`, and the normalized `GhEx.Error`.
- Convenience resources: `GhEx.Issues` and `GhEx.PullRequests`, thin wrappers over
  `GhEx.REST` for the common Issues and Pull Requests paths.
- Opt-in GitHub-aware rate-limit retry: `GhEx.RateLimit.retry/2`, a `Req`-compatible
  policy that backs off on secondary rate limits (a `403` with `retry-after` or
  `x-ratelimit-remaining: 0`).

[Unreleased]: https://github.com/joshrotenberg/gh_ex
