# Extending gh_ex

`gh_ex` favors a small, capable core over a wrapper for every GitHub endpoint.
The generic REST client can call the full API today, while resource modules add
names and request shapes for frequently used operations. You do not need to wait
for a built-in wrapper to use an endpoint.

The modules and functions in this guide are documented public API. They are the
supported boundary for application-owned resource modules and third-party wrapper
packages.

## Call an unwrapped endpoint

Use the function matching the HTTP method and pass the path relative to the
client's REST URL:

```elixir
GhEx.REST.get(client, "/repos/o/r/environments", params: [per_page: 50])

GhEx.REST.post(client, "/repos/o/r/dispatches",
  json: %{event_type: "deploy", client_payload: %{environment: "staging"}}
)

GhEx.REST.patch(client, "/repos/o/r/issues/42", json: %{state: "closed"})
GhEx.REST.put(client, "/repos/o/r/environments/staging", json: %{wait_timer: 30})
GhEx.REST.delete(client, "/repos/o/r/actions/artifacts/123")
```

The five verb functions normalize successful responses to
`{:ok, body, %GhEx.REST.Meta{}}`. API failures return
`{:error, %GhEx.Error{}}`, and transport failures return the underlying
exception. Per-call options pass through to `Req`, including `:params`,
`:headers`, `:json`, and test plugs.

## Choose the response level

Use the highest-level function that preserves the behavior you need.

### Normalized calls

`GhEx.REST.get/3`, `post/3`, `patch/3`, `put/3`, and `delete/3` handle JSON,
normalize non-success responses, and return response metadata. The metadata
includes status, headers, pagination links, rate-limit state, ETag, and
Last-Modified values.

```elixir
case GhEx.REST.get(client, "/repos/o/r/environments") do
  {:ok, body, meta} -> {:ok, body, meta.rate_limit}
  {:error, %GhEx.Error{status: 404}} -> :repository_not_found
  {:error, exception} -> {:transport_error, exception}
end
```

### Raw responses

Use `GhEx.REST.raw/4` when the status itself is data, when you need binary or
redirect handling, or when an expected `404` should not become `GhEx.Error`.
It returns the unnormalized `Req.Response` for every HTTP status.

```elixir
{:ok, response} =
  GhEx.REST.raw(client, :get, "/repos/o/r/releases/assets/123",
    headers: [{"accept", "application/octet-stream"}]
  )

case response.status do
  200 -> {:ok, response.body}
  302 -> {:redirect, Req.Response.get_header(response, "location")}
  404 -> :not_found
end
```

The raw response composes with the same public metadata helpers used by the
normalized core:

```elixir
links = GhEx.Pagination.links(response)
rate_limit = GhEx.RateLimit.from_response(response)
```

### Lazy pagination

`GhEx.REST.stream/3` follows same-origin `Link` headers and yields individual
items. Bare-array endpoints need only the path. For an object-wrapped response,
pass the key containing the array as `:items`.

```elixir
client
|> GhEx.REST.stream("/repos/o/r/environments", items: "environments")
|> Stream.map(& &1["name"])
|> Enum.to_list()
```

A stream raises `GhEx.Error` if a page fails because an enumerable cannot return
the normal `{:error, reason}` tuple. Use a verb function and `meta.links` when
you need manual error recovery or pacing between pages.

## Write a resource module

Application-owned wrappers use the same client-first plain functions as built-in
modules. This example wraps repository environments without extending or
subclassing any gh_ex type:

```elixir
defmodule MyApp.GitHub.Environments do
  alias GhEx.{Client, REST}

  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/environments", opts)
  end

  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(
      client,
      "/repos/#{owner}/#{repo}/environments",
      Keyword.put(opts, :items, "environments")
    )
  end

  @spec create_or_update(
          Client.t(),
          String.t(),
          String.t(),
          String.t(),
          map(),
          keyword()
        ) :: REST.result()
  def create_or_update(client, owner, repo, environment, attrs, opts \\ []) do
    environment = URI.encode(environment, &URI.char_unreserved?/1)

    REST.put(
      client,
      "/repos/#{owner}/#{repo}/environments/#{environment}",
      Keyword.put(opts, :json, attrs)
    )
  end
end
```

The wrapper owns the path and JSON body while leaving transport options open to
the caller. It returns the same result shape as the core, so callers can combine
it with built-in modules without special handling.

## Test a resource module

Resource modules use `Req.Test` exactly like gh_ex itself. Add Plug to test
dependencies and build the client with `GhEx.Testing.client/1`:

```elixir
defmodule MyApp.GitHub.EnvironmentsTest do
  use ExUnit.Case, async: true

  test "creates or updates an environment" do
    Req.Test.stub(__MODULE__.Stub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/repos/o/r/environments/staging%2Feu"

      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(raw) == %{"wait_timer" => 30}

      Req.Test.json(conn, %{"name" => "staging/eu", "protection_rules" => []})
    end)

    client = GhEx.Testing.client(__MODULE__.Stub)

    assert {:ok, %{"name" => "staging/eu"}, _meta} =
             MyApp.GitHub.Environments.create_or_update(
               client,
               "o",
               "r",
               "staging/eu",
               %{wait_timer: 30}
             )
  end
end
```

See the [Testing](testing.md), [Pagination](pagination.md), and
[Error handling](error-handling.md) guides for conditional responses,
rate-limit fixtures, manual pagination, and error classification.
