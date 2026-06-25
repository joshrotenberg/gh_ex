# Error handling

Every `GhEx.REST` and `GhEx.GraphQL` call returns `{:ok, body, meta}` on success
or `{:error, reason}` on failure.

## Reasons

`reason` is one of:

- a `GhEx.Error` for an API error response, or
- a `Req` exception (for example `Req.TransportError`) for a transport failure.

`GhEx.Error` carries `:status`, `:message`, `:body`, `:errors`, and
`:documentation_url`:

```elixir
case GhEx.REST.get(client, "/repos/o/does-not-exist") do
  {:ok, repo, _meta} -> repo
  {:error, %GhEx.Error{status: 404}} -> :not_found
  {:error, %GhEx.Error{} = err} -> {:error, Exception.message(err)}
  {:error, exception} -> {:transport_error, exception}
end
```

## GraphQL errors

GraphQL answers with HTTP 200 even on failure, so a response carrying a non-empty
`errors` array becomes `{:error, %GhEx.Error{}}` (the same struct REST uses). Any
partial `data` is preserved on the error's `:body` as
`%{"data" => ..., "errors" => ...}`.

## Errors as exceptions

`GhEx.Error` is also an exception, so the streaming helpers that cannot return an
`:error` tuple raise it:

```elixir
try do
  client |> GhEx.REST.stream("/repos/o/r/issues") |> Enum.to_list()
rescue
  e in GhEx.Error -> {:error, e.status}
end
```

## Rate limits

`Req` already retries ordinary transient errors. To also back off on GitHub's
secondary rate limits (a `403` with `retry-after` or `x-ratelimit-remaining: 0`),
opt into `GhEx.RateLimit.retry/2`:

```elixir
GhEx.new(
  auth: {:token, token},
  req_options: [retry: &GhEx.RateLimit.retry/2]
)
```

`Req` bounds the attempts with `:max_retries` (default 3).
