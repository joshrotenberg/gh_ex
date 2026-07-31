# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
semantic versioning.

## [0.3.4](https://github.com/joshrotenberg/gh_ex/compare/v0.3.3...v0.3.4) (2026-07-31)


### Features

* add Actions deployment approval helpers ([#144](https://github.com/joshrotenberg/gh_ex/issues/144)) ([82c2387](https://github.com/joshrotenberg/gh_ex/commit/82c2387a999db3877ab5667f307669d0ae87dda5)), closes [#121](https://github.com/joshrotenberg/gh_ex/issues/121)
* add check failure-triage helpers ([#139](https://github.com/joshrotenberg/gh_ex/issues/139)) ([180483c](https://github.com/joshrotenberg/gh_ex/commit/180483c0dcdcf0339949ec38a5a2120c95720536))
* add check-run lookup by app and name ([#140](https://github.com/joshrotenberg/gh_ex/issues/140)) ([b649abd](https://github.com/joshrotenberg/gh_ex/commit/b649abda86def83f1a14bfcef6f8b06e916cccc1))
* add code security alerts ([#150](https://github.com/joshrotenberg/gh_ex/issues/150)) ([e4ddcbd](https://github.com/joshrotenberg/gh_ex/commit/e4ddcbde55e7c23f6cb37a4f5e0c02d037d3b026))
* add collaborator authorization helpers ([#151](https://github.com/joshrotenberg/gh_ex/issues/151)) ([e57305d](https://github.com/joshrotenberg/gh_ex/commit/e57305d900c6b236f032a6a219a56a9db533886e))
* add deployments and deployment statuses ([#145](https://github.com/joshrotenberg/gh_ex/issues/145)) ([723bb3e](https://github.com/joshrotenberg/gh_ex/commit/723bb3ed5b1b789daf23ec75356e616de8502561)), closes [#126](https://github.com/joshrotenberg/gh_ex/issues/126)
* add GhEx.Error.classify/1 and retryable?/1 ([#129](https://github.com/joshrotenberg/gh_ex/issues/129)) ([8364294](https://github.com/joshrotenberg/gh_ex/commit/8364294e431e858eef080735b7c41a7f15992278)), closes [#124](https://github.com/joshrotenberg/gh_ex/issues/124)
* add issue comment and assignee helpers ([#142](https://github.com/joshrotenberg/gh_ex/issues/142)) ([7824858](https://github.com/joshrotenberg/gh_ex/commit/78248588daa858a395ab271af3d75505d02599e9))
* add pull request merge-flow helpers ([#138](https://github.com/joshrotenberg/gh_ex/issues/138)) ([1b14542](https://github.com/joshrotenberg/gh_ex/commit/1b1454281311d1a873c02050a5ce0e310cb5bc8f))
* add release asset upload ([#146](https://github.com/joshrotenberg/gh_ex/issues/146)) ([8b3ba45](https://github.com/joshrotenberg/gh_ex/commit/8b3ba452a760cc9288ae1b619a53dc30b45cec19)), closes [#118](https://github.com/joshrotenberg/gh_ex/issues/118)
* add repository event polling ([#147](https://github.com/joshrotenberg/gh_ex/issues/147)) ([70f91e9](https://github.com/joshrotenberg/gh_ex/commit/70f91e918d75341bf3a5621f7d71f6d7b2266dbd)), closes [#120](https://github.com/joshrotenberg/gh_ex/issues/120)
* add repository hook management ([#149](https://github.com/joshrotenberg/gh_ex/issues/149)) ([0736385](https://github.com/joshrotenberg/gh_ex/commit/0736385a642e53f5cb1ced6f87c572e87522395f))
* add repository label management ([#143](https://github.com/joshrotenberg/gh_ex/issues/143)) ([7780923](https://github.com/joshrotenberg/gh_ex/commit/7780923ec2292da8af6ca6a0cdf0ee165027fddb))
* add Req.Test testing helpers ([#141](https://github.com/joshrotenberg/gh_ex/issues/141)) ([4e25a9a](https://github.com/joshrotenberg/gh_ex/commit/4e25a9ad8b8072da7102aee83c1b67b2e1eb9c4a))


### Bug Fixes

* provide repository context to release CLI commands ([#154](https://github.com/joshrotenberg/gh_ex/issues/154)) ([0e93bb5](https://github.com/joshrotenberg/gh_ex/commit/0e93bb53c8c71f87690d27eef98b9c143e73009f))
* scope release CI dispatch to the repository ([#153](https://github.com/joshrotenberg/gh_ex/issues/153)) ([f709ce2](https://github.com/joshrotenberg/gh_ex/commit/f709ce2d4623c6b862a4cc79ac035f9bae1c51bd))

## [0.3.3](https://github.com/joshrotenberg/gh_ex/compare/v0.3.2...v0.3.3) (2026-07-01)


### Features

* add GhEx.Notifications for consuming the notifications inbox ([#104](https://github.com/joshrotenberg/gh_ex/issues/104)) ([2c0668e](https://github.com/joshrotenberg/gh_ex/commit/2c0668e9be3b4436a8ec28dd84ef875e353cf956))
* add GhEx.Notifications thread subscription management ([#106](https://github.com/joshrotenberg/gh_ex/issues/106)) ([a40efc4](https://github.com/joshrotenberg/gh_ex/commit/a40efc4cfb635a625c664960c6adcf81c6cf8980))

## [0.3.2](https://github.com/joshrotenberg/gh_ex/compare/v0.3.1...v0.3.2) (2026-06-29)


### Features

* add GhEx.RateLimit.delay_until_reset/2 for opt-in proactive pacing ([#101](https://github.com/joshrotenberg/gh_ex/issues/101)) ([dedf9d5](https://github.com/joshrotenberg/gh_ex/commit/dedf9d5d8d04715e00241b3841f88817ac95513a))
* add stream_* auto-pagination companions to the convenience modules ([#91](https://github.com/joshrotenberg/gh_ex/issues/91)) ([7235196](https://github.com/joshrotenberg/gh_ex/commit/7235196145cd5f993f5715e080732f44ab87bb9d)), closes [#66](https://github.com/joshrotenberg/gh_ex/issues/66)
* default per_page to 100 in REST.stream/3 ([#92](https://github.com/joshrotenberg/gh_ex/issues/92)) ([be06994](https://github.com/joshrotenberg/gh_ex/commit/be0699459c4ed24104cfd433439bcb2d6ba03dd0)), closes [#70](https://github.com/joshrotenberg/gh_ex/issues/70)
* emit :telemetry spans around REST and GraphQL requests ([#96](https://github.com/joshrotenberg/gh_ex/issues/96)) ([e54733b](https://github.com/joshrotenberg/gh_ex/commit/e54733b8d3d10a62a0a746ecfb1fc20b67e1cf68))
* handle 304 Not Modified and expose ETag/Last-Modified on REST meta ([#97](https://github.com/joshrotenberg/gh_ex/issues/97)) ([59f5bf2](https://github.com/joshrotenberg/gh_ex/commit/59f5bf2a05e941854388a1ecb526d50ed7430dd9)), closes [#68](https://github.com/joshrotenberg/gh_ex/issues/68)


### Bug Fixes

* accept :params as a map in GhEx.Search ([#88](https://github.com/joshrotenberg/gh_ex/issues/88)) ([b563252](https://github.com/joshrotenberg/gh_ex/commit/b563252aa75014f8446d09e014da07f050493dc2))
* detect body-only secondary rate limit in RateLimit.retry/2 ([#98](https://github.com/joshrotenberg/gh_ex/issues/98)) ([be52b01](https://github.com/joshrotenberg/gh_ex/commit/be52b01e85f3f9e12c242ec364eee00884427c3a))
* halt GraphQL.stream when :path traverses a non-map intermediate ([#89](https://github.com/joshrotenberg/gh_ex/issues/89)) ([95262a4](https://github.com/joshrotenberg/gh_ex/commit/95262a4d63c984a44e0088d54b2805de380b8e97)), closes [#64](https://github.com/joshrotenberg/gh_ex/issues/64)
* halt GraphQL.stream when endCursor is nil despite hasNextPage ([#81](https://github.com/joshrotenberg/gh_ex/issues/81)) ([cfc3227](https://github.com/joshrotenberg/gh_ex/commit/cfc32270750dc07d6db771fb12b8127033b9b861))
* label a GraphQL 200 with a non-map body as a shape error, not HTTP 200 ([#84](https://github.com/joshrotenberg/gh_ex/issues/84)) ([6d0264e](https://github.com/joshrotenberg/gh_ex/commit/6d0264e9e841a23b8b717cefc4b8e637b7caf9bf))
* redact credentials from GhEx.Client and cached token inspect ([#77](https://github.com/joshrotenberg/gh_ex/issues/77)) ([a514f88](https://github.com/joshrotenberg/gh_ex/commit/a514f88bf063ae25c94c38278009c78481292ff8))
* refuse cross-host pagination URL in REST.stream/3 ([#85](https://github.com/joshrotenberg/gh_ex/issues/85)) ([f9cc218](https://github.com/joshrotenberg/gh_ex/commit/f9cc218709d77e1088edb0cbb8feda29c571d6d8))
* reject a zero or negative JWT :lifetime that mints an expired token ([#90](https://github.com/joshrotenberg/gh_ex/issues/90)) ([c81d071](https://github.com/joshrotenberg/gh_ex/commit/c81d071fa9ab765a217c78c147b89e20424a9fe5))
* run installation-token mint off the GenServer to avoid 5s call timeout ([#82](https://github.com/joshrotenberg/gh_ex/issues/82)) ([db15e64](https://github.com/joshrotenberg/gh_ex/commit/db15e648cb5aec6c81d58453f2bb91d6a3c5b0fa))
* URL-encode the file path in GhEx.Contents ([#83](https://github.com/joshrotenberg/gh_ex/issues/83)) ([ff3e0b8](https://github.com/joshrotenberg/gh_ex/commit/ff3e0b885de0cdceec90e62ffc8523eabea93437))

## [0.3.1](https://github.com/joshrotenberg/gh_ex/compare/v0.3.0...v0.3.1) (2026-06-26)


### Features

* add Actions and Search convenience modules ([#54](https://github.com/joshrotenberg/gh_ex/issues/54)) ([1fa2755](https://github.com/joshrotenberg/gh_ex/commit/1fa2755797a2372fc39dfbe9d19f4953f2c5ce2b))
* add Users, Organizations, Teams, Checks, Statuses, and Gists convenience modules ([#57](https://github.com/joshrotenberg/gh_ex/issues/57)) ([a35f7a3](https://github.com/joshrotenberg/gh_ex/commit/a35f7a38821d991ba9f615ad3e73be05f4345e4d))

## [0.3.0](https://github.com/joshrotenberg/gh_ex/compare/v0.2.1...v0.3.0) (2026-06-26)


### Features

* add Repositories, Contents, and Releases convenience modules ([#52](https://github.com/joshrotenberg/gh_ex/issues/52)) ([a95e241](https://github.com/joshrotenberg/gh_ex/commit/a95e24113d3f6bfd3f228f882c2303540d21cedd))

## [0.2.1](https://github.com/joshrotenberg/gh_ex/compare/v0.2.0...v0.2.1) (2026-06-25)


### Bug Fixes

* send a numeric App ID issuer as a JSON integer in the JWT ([#47](https://github.com/joshrotenberg/gh_ex/issues/47)) ([8874dd9](https://github.com/joshrotenberg/gh_ex/commit/8874dd927b8e2fa6f1ec40eb0bb7657443878a9c))

## [0.2.0](https://github.com/joshrotenberg/gh_ex/compare/v0.1.0...v0.2.0) (2026-06-25)


### Features

* add GhEx.REST.raw/4 and GhEx.RateLimit.get/1 ([58550fd](https://github.com/joshrotenberg/gh_ex/commit/58550fd00301ccd7c366f7ba38d207d9eded4588))
* add GhEx.Webhooks for signature verification and payload parsing ([5a01e07](https://github.com/joshrotenberg/gh_ex/commit/5a01e078866ee2158f35a62b368a6ebc22035484))

## [0.1.0] - 2026-06-24

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

[0.1.0]: https://github.com/joshrotenberg/gh_ex/releases/tag/v0.1.0
