# Notifications

`GhEx.Notifications` wraps the GitHub Notifications REST API for consuming the
authenticated user's inbox: list threads, mark them read or done, and read
GitHub's suggested poll interval. It is a set of thin `GhEx.REST` wrappers, so it
returns the usual `{:ok, body, meta}` / `{:error, reason}` shape and passes
`opts` through to `Req`.

```elixir
{:ok, threads, _meta} = GhEx.Notifications.list(client, params: [participating: true])

for t <- threads do
  IO.puts("#{t["reason"]}: #{t["subject"]["title"]}")
end
```

A thread is a pointer, not a payload. It tells you *that* something happened
(`reason`, `subject.type`, `subject.url`) but not the details. To act on it,
fetch the subject:

```elixir
{:ok, pr, _} = GhEx.REST.get(client, thread["subject"]["url"])
```

## Polling politely

The inbox has no webhook, so consuming it means polling. GitHub asks you to do
three things, and gh_ex gives you each piece:

1. **Poll conditionally.** Send the previous response's validator so an unchanged
   inbox is cheap and does not count against your rate limit. A `304` comes back
   as `{:ok, :not_modified, meta}` (distinct from a normal `{:ok, body, meta}`).
2. **Respect `X-Poll-Interval`.** `poll_interval/2` reads the header, the seconds
   GitHub wants you to wait before the next poll.
3. **Back off on the rate limit.** `GhEx.RateLimit.delay_until_reset/2` is the
   backstop when the bucket runs low.

gh_ex supplies these pieces; the loop is yours. A minimal poller:

```elixir
defmodule Inbox do
  def poll(client, last_modified \\ nil) do
    headers = if last_modified, do: [{"if-modified-since", last_modified}], else: []

    case GhEx.Notifications.list(client, headers: headers, params: [participating: true]) do
      {:ok, :not_modified, meta} ->
        wait_and_repeat(client, last_modified, meta)

      {:ok, threads, meta} ->
        Enum.each(threads, &handle/1)
        wait_and_repeat(client, meta.last_modified, meta)
    end
  end

  defp wait_and_repeat(client, last_modified, meta) do
    Process.sleep(GhEx.Notifications.poll_interval(meta) * 1000)
    poll(client, last_modified)
  end

  defp handle(thread), do: IO.inspect(thread["subject"]["title"])
end
```

In a job system the same shape is non-blocking: return `{:snooze,
poll_interval(meta)}` instead of sleeping, and store `meta.last_modified` (or
`meta.etag`) on the job for the next run.

## What is not here

`GhEx.Notifications` is a client, not a consumer engine: no poll loop, dedup, or
state ship with it.

Thread subscriptions are supported: `get_thread_subscription/3`,
`set_thread_subscription/4` (`%{ignored: true}` to mute, `%{ignored: false}` to
subscribe), and `delete_thread_subscription/3`. Repository watch subscriptions,
which govern what enters the inbox at the repo level, belong to the Watching API
and are tracked separately.
