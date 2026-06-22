# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow semantic versioning once it reaches a release.

## [Unreleased]

### Added

- REST core (`GH.REST`): `get/post/patch/put/delete` returning `{:ok, body, meta}`
  / `{:error, reason}`, and `stream/3` for `Link`-header auto-pagination.
- GraphQL core (`GH.GraphQL`): `query/3` with variable passing and 200-with-errors
  normalization into `GH.Error`, and `stream/4` for `pageInfo` cursor pagination.
- Client and request plumbing: `GH.new/1`, `GH.Client`, `GH.Request`, with the
  required GitHub headers and bearer auth injected on every call.
- Auth (`GH.Auth`): `{:token, t}` and `{:app, issuer, pem}` credential forms.
- GitHub App auth: `GH.JWT.mint/3` (OTP-native RS256, no JOSE dependency) and
  `GH.App.installation_token/3` / `installation_client/3` for one-shot
  installation access tokens.
- Transparent installation-token caching: `GH.App.installation/3` returns a
  client that mints, caches, and refreshes its token through a `GH.TokenCache`.
  `GH.TokenCache.ETS` is the default supervised cache (single-flight minting);
  the behaviour lets you plug in a clustered backend.
- Metadata and errors: `GH.REST.Meta`, `GH.GraphQL.Meta`, `GH.RateLimit`,
  `GH.Pagination`, and the normalized `GH.Error`.

[Unreleased]: https://github.com/joshrotenberg/gh_ex
