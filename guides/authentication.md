# Authentication

`GhEx.new/1` accepts three credential forms via `:auth`.

## Token

A classic or fine-grained personal access token, or an OAuth token:

```elixir
client = GhEx.new(auth: {:token, token})
```

## GitHub App

A GitHub App authenticates as itself with a short-lived RS256 JWT, minted from
the app's private key with OTP crypto (no JOSE dependency):

```elixir
app = GhEx.new(auth: {:app, client_id_or_app_id, File.read!("app-private-key.pem")})
```

The JWT is minted per request inside `GhEx.Auth.resolve/1`. A malformed key
returns `{:error, :invalid_pem}` rather than raising.

## Installation

To act as an installation, use a client that mints and caches the installation
access token (valid one hour) and refreshes it before expiry. This needs a
running token cache. Add the default ETS cache to your supervision tree:

```elixir
children = [
  GhEx.TokenCache.ETS
  # or, to run more than one or pick the name:
  # {GhEx.TokenCache.ETS, name: MyApp.GitHubTokens}
]
```

Then build an installation client:

```elixir
inst = GhEx.App.installation(app, installation_id, cache: GhEx.TokenCache.ETS)
GhEx.REST.get(inst, "/installation/repositories")
```

Construction does no I/O; the token is minted on the first request and reused
until it nears expiry.

## Custom cache backend

`GhEx.TokenCache` is a behaviour. Back it with your own module (for example
Nebulex or Redis) to share tokens across a cluster, without `gh_ex` depending on
a cache library. Pass `{module, ref}` as the `:cache` to name a specific
instance.

## Stateless primitives

To own the token lifecycle yourself:

```elixir
# a token-auth client scoped to the installation, plus its expiry
{:ok, inst, _expires_at} = GhEx.App.installation_client(app, installation_id)

# or the raw token body, optionally scoped to repositories/permissions
{:ok, body} =
  GhEx.App.installation_token(app, installation_id, json: %{repositories: ["gh_ex"]})
```
