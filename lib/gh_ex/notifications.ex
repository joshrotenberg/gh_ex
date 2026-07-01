defmodule GhEx.Notifications do
  @moduledoc """
  Convenience functions for the GitHub Notifications REST API.

  Each function is a thin wrapper over `GhEx.REST` that fills in the endpoint
  path. They return the same `{:ok, body, meta}` / `{:error, reason}` shape as
  `GhEx.REST` and pass `opts` through to `Req`, so `:params`, headers, and a
  `Req.Test` plug all work. For an endpoint without a wrapper, call `GhEx.REST`
  directly.

  This module covers *consuming* the inbox. It has no poll loop, dedup, or state
  of its own: a consumer supplies those (an Oban worker, a `GenServer`, ...). For
  polite polling, gh_ex already gives you the pieces:

    * conditional requests: send `If-Modified-Since` (or `If-None-Match`) via
      `headers:`; an unchanged inbox returns `{:ok, :not_modified, meta}` and does
      not count against the rate limit.
    * `poll_interval/2` reads GitHub's `X-Poll-Interval` header, the seconds it
      asks you to wait before polling again.
    * `GhEx.RateLimit.delay_until_reset/2` is the rate-limit backstop.

  See `guides/notifications.md` for the full pattern.

  A notification thread is a pointer ("thread X had activity, reason Y, subject
  URL"), not a payload. Fetch the subject (`thread["subject"]["url"]`) to learn
  what changed; that is the consumer's job.
  """

  alias GhEx.{Client, REST}

  @type thread_ref :: integer() | String.t()

  @doc """
  Lists notifications for the authenticated user (`GET /notifications`).

  Use `params:` for `all`, `participating`, `since`, `before`, `per_page`, and
  `page`. Pass `headers: [{"if-modified-since", last_modified}]` (or
  `if-none-match`) to poll conditionally; an unchanged inbox comes back as
  `{:ok, :not_modified, meta}`.
  """
  @spec list(Client.t(), keyword()) :: REST.result()
  def list(client, opts \\ []) do
    REST.get(client, "/notifications", opts)
  end

  @doc """
  Lists notifications in a single repository
  (`GET /repos/{owner}/{repo}/notifications`). Accepts the same `params:` as
  `list/2`.
  """
  @spec list_repo(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_repo(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/notifications", opts)
  end

  @doc "Gets a single notification thread (`GET /notifications/threads/{id}`)."
  @spec get_thread(Client.t(), thread_ref(), keyword()) :: REST.result()
  def get_thread(client, thread_id, opts \\ []) do
    REST.get(client, "/notifications/threads/#{thread_id}", opts)
  end

  @doc "Marks a thread as read (`PATCH /notifications/threads/{id}`)."
  @spec mark_thread_read(Client.t(), thread_ref(), keyword()) :: REST.result()
  def mark_thread_read(client, thread_id, opts \\ []) do
    REST.patch(client, "/notifications/threads/#{thread_id}", opts)
  end

  @doc """
  Marks a thread as done (`DELETE /notifications/threads/{id}`), removing it from
  the inbox.
  """
  @spec mark_thread_done(Client.t(), thread_ref(), keyword()) :: REST.result()
  def mark_thread_done(client, thread_id, opts \\ []) do
    REST.delete(client, "/notifications/threads/#{thread_id}", opts)
  end

  @doc """
  Marks all notifications as read (`PUT /notifications`).

  Pass `last_read_at:` (an ISO 8601 timestamp) to only mark notifications updated
  at or before that time; it defaults to now on GitHub's side.
  """
  @spec mark_read(Client.t(), keyword()) :: REST.result()
  def mark_read(client, opts \\ []) do
    {opts, json} = pop_read_body(opts)
    REST.put(client, "/notifications", Keyword.put(opts, :json, json))
  end

  @doc """
  Marks a repository's notifications as read
  (`PUT /repos/{owner}/{repo}/notifications`). Accepts `last_read_at:` like
  `mark_read/2`.
  """
  @spec mark_repo_read(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def mark_repo_read(client, owner, repo, opts \\ []) do
    {opts, json} = pop_read_body(opts)
    REST.put(client, "/repos/#{owner}/#{repo}/notifications", Keyword.put(opts, :json, json))
  end

  @doc "Gets a thread's subscription (`GET /notifications/threads/{id}/subscription`)."
  @spec get_thread_subscription(Client.t(), thread_ref(), keyword()) :: REST.result()
  def get_thread_subscription(client, thread_id, opts \\ []) do
    REST.get(client, "/notifications/threads/#{thread_id}/subscription", opts)
  end

  @doc """
  Sets a thread's subscription (`PUT /notifications/threads/{id}/subscription`).

  `attrs` is the JSON body: `%{ignored: true}` mutes the thread, `%{ignored: false}`
  subscribes to it.
  """
  @spec set_thread_subscription(Client.t(), thread_ref(), map(), keyword()) :: REST.result()
  def set_thread_subscription(client, thread_id, attrs, opts \\ []) do
    REST.put(
      client,
      "/notifications/threads/#{thread_id}/subscription",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc """
  Deletes a thread's subscription
  (`DELETE /notifications/threads/{id}/subscription`), unsubscribing without
  muting.
  """
  @spec delete_thread_subscription(Client.t(), thread_ref(), keyword()) :: REST.result()
  def delete_thread_subscription(client, thread_id, opts \\ []) do
    REST.delete(client, "/notifications/threads/#{thread_id}/subscription", opts)
  end

  @doc """
  Reads the `X-Poll-Interval` response header off a `GhEx.REST.Meta`, the number
  of seconds GitHub asks you to wait before polling `/notifications` again.

  Returns `default` (60) when the header is absent or unparseable. gh_ex parses
  the header; the caller decides what to do with it (for example
  `Process.sleep/1`, or an Oban `{:snooze, seconds}`).
  """
  @spec poll_interval(REST.Meta.t(), non_neg_integer()) :: non_neg_integer()
  def poll_interval(%REST.Meta{headers: headers}, default \\ 60) do
    case header_value(headers, "x-poll-interval") do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {seconds, _rest} when seconds >= 0 -> seconds
          _ -> default
        end

      _ ->
        default
    end
  end

  defp pop_read_body(opts) do
    case Keyword.pop(opts, :last_read_at) do
      {nil, opts} -> {opts, %{}}
      {last_read_at, opts} -> {opts, %{last_read_at: last_read_at}}
    end
  end

  defp header_value(headers, name) when is_map(headers) do
    case Map.get(headers, name) do
      [value | _] -> value
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp header_value(_headers, _name), do: nil
end
