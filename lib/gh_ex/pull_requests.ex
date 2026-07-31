defmodule GhEx.PullRequests do
  @moduledoc """
  Convenience functions for the GitHub Pull Requests REST API.

  Each function is a thin wrapper over `GhEx.REST` that fills in the endpoint
  path. They return the same `{:ok, body, meta}` / `{:error, reason}` shape as
  `GhEx.REST` and pass `opts` through to `Req`, so `:params`, headers, and a
  `Req.Test` plug all work. For an endpoint without a wrapper, call `GhEx.REST`
  directly.
  """

  alias GhEx.{Client, REST}

  @diff_media_type "application/vnd.github.diff"
  @patch_media_type "application/vnd.github.patch"

  @type number_ref :: integer() | String.t()

  @doc """
  Lists pull requests in a repository. Use `params:` for `state`, `base`, `head`,
  and the other query options.
  """
  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls", opts)
  end

  @doc """
  Auto-paginates pull requests in a repository into a lazy `Stream` of
  individual pull requests (see `GhEx.REST.stream/3`).
  """
  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/pulls", opts)
  end

  @doc "Gets a single pull request by number."
  @spec get(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def get(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}", opts)
  end

  @doc """
  Gets a pull request's unified diff as a string.

  This forces GitHub's `application/vnd.github.diff` media type while
  preserving any other request headers supplied through `opts`.
  """
  @spec get_diff(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def get_diff(client, owner, repo, number, opts \\ []) do
    REST.get(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}",
      with_accept(opts, @diff_media_type)
    )
  end

  @doc """
  Gets a pull request's mailbox-format patch as a string.

  This forces GitHub's `application/vnd.github.patch` media type while
  preserving any other request headers supplied through `opts`.
  """
  @spec get_patch(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def get_patch(client, owner, repo, number, opts \\ []) do
    REST.get(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}",
      with_accept(opts, @patch_media_type)
    )
  end

  @doc "Creates a pull request. `attrs` is the JSON body (title, head, base, body, draft, ...)."
  @spec create(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/pulls", Keyword.put(opts, :json, attrs))
  end

  @doc "Updates a pull request. `attrs` may set title, body, state, base, and so on."
  @spec update(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) ::
          REST.result()
  def update(client, owner, repo, number, attrs, opts \\ []) do
    REST.patch(client, "/repos/#{owner}/#{repo}/pulls/#{number}", Keyword.put(opts, :json, attrs))
  end

  @doc """
  Checks whether a pull request has been merged.

  Returns `{:ok, true, meta}` for GitHub's `204` response and
  `{:ok, false, meta}` for its `404` response. Other failures retain the
  standard `{:error, reason}` shape.
  """
  @spec is_merged(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  # GitHub's endpoint and issue #116 deliberately use the `is_merged` name.
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_merged(client, owner, repo, number, opts \\ []) do
    REST.present?(client, "/repos/#{owner}/#{repo}/pulls/#{number}/merge", opts)
  end

  @doc """
  Merges a standalone pull request using GitHub's legacy synchronous endpoint.

  `attrs` may set `commit_title`, `commit_message`, and `merge_method`
  (`"merge"`, `"squash"`, or `"rebase"`). This endpoint cannot merge a stacked
  pull request; use `merge_async/6` for stacks.
  """
  @spec merge(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) :: REST.result()
  def merge(client, owner, repo, number, attrs \\ %{}, opts \\ []) do
    REST.put(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/merge",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc """
  Submits an asynchronous merge request.

  For a stacked pull request, GitHub merges the selected pull request and every
  unmerged pull request below it as one atomic operation. `attrs` may set
  `merge_method` (`"merge"`, `"squash"`, or `"rebase"`), `merge_action`
  (`"default"`, `"direct_merge"`, or `"merge_queue"`), `commit_title`,
  `commit_message`, and `sha`.

  A `202` response has status `"pending"` and includes a UUID. Poll it with
  `get_merge_result/6` until the status is `"merged"`, `"enqueued"`, or
  `"failed"`.

  GitHub may return a `409` with the existing pending request when a merge is
  already running. As with every non-2xx REST response in gh_ex, that is returned
  as `{:error, %GhEx.Error{}}`; the pending result remains available in the
  error's `body` field.
  """
  @spec merge_async(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) ::
          REST.result()
  def merge_async(client, owner, repo, number, attrs \\ %{}, opts \\ []) do
    REST.put(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/merge-async",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc """
  Gets the current result of an asynchronous merge request.

  Pending results are retained by GitHub for 24 hours after their most recent
  update.
  """
  @spec get_merge_result(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          String.t(),
          keyword()
        ) :: REST.result()
  def get_merge_result(client, owner, repo, number, uuid, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}/merge-async/#{uuid}", opts)
  end

  @doc "Lists the commits on a pull request. GitHub returns at most 250 commits."
  @spec list_commits(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def list_commits(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}/commits", opts)
  end

  @doc "Auto-paginates the commits on a pull request into a lazy `Stream`."
  @spec stream_commits(Client.t(), String.t(), String.t(), number_ref(), keyword()) ::
          Enumerable.t()
  def stream_commits(client, owner, repo, number, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/pulls/#{number}/commits", opts)
  end

  @doc "Lists the files changed in a pull request."
  @spec list_files(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def list_files(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}/files", opts)
  end

  @doc "Auto-paginates the files changed in a pull request into a lazy `Stream`."
  @spec stream_files(Client.t(), String.t(), String.t(), number_ref(), keyword()) ::
          Enumerable.t()
  def stream_files(client, owner, repo, number, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/pulls/#{number}/files", opts)
  end

  @doc """
  Lists review comments on a pull request.

  These are comments anchored to a diff, not issue comments from the pull
  request's Conversation tab. Use `params:` for `sort`, `direction`, and
  `since`.
  """
  @spec list_comments(Client.t(), String.t(), String.t(), number_ref(), keyword()) ::
          REST.result()
  def list_comments(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}/comments", opts)
  end

  @doc "Auto-paginates a pull request's review comments into a lazy `Stream`."
  @spec stream_comments(Client.t(), String.t(), String.t(), number_ref(), keyword()) ::
          Enumerable.t()
  def stream_comments(client, owner, repo, number, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/pulls/#{number}/comments", opts)
  end

  @doc """
  Creates a review comment anchored to a pull request diff.

  `attrs` requires `body`, `commit_id`, and `path`. For a line comment, provide
  `line` and `side` (`"LEFT"` or `"RIGHT"`). A multi-line comment also uses
  `start_line` and `start_side`. For a file-level comment, set
  `subject_type: "file"`; `line` is then optional. GitHub is closing down the
  older `position` parameter, so prefer the line-based fields.
  """
  @spec create_comment(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) ::
          REST.result()
  def create_comment(client, owner, repo, number, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/comments",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc """
  Replies to a top-level review comment.

  GitHub does not support replies to replies; `comment_id` must identify the
  top-level comment in the thread.
  """
  @spec reply_to_comment(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          number_ref(),
          String.t(),
          keyword()
        ) :: REST.result()
  def reply_to_comment(client, owner, repo, number, comment_id, body, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/comments/#{comment_id}/replies",
      Keyword.put(opts, :json, %{body: body})
    )
  end

  @doc """
  Requests reviews from users and/or teams.

  `attrs` may contain `reviewers`, an array of user logins, and
  `team_reviewers`, an array of team slugs.
  """
  @spec request_reviewers(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) ::
          REST.result()
  def request_reviewers(client, owner, repo, number, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/requested_reviewers",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc """
  Removes review requests from users and/or teams.

  `attrs` accepts the same `reviewers` and `team_reviewers` arrays as
  `request_reviewers/6`.
  """
  @spec remove_requested_reviewers(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          map(),
          keyword()
        ) :: REST.result()
  def remove_requested_reviewers(client, owner, repo, number, attrs, opts \\ []) do
    REST.delete(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/requested_reviewers",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Lists the reviews on a pull request."
  @spec list_reviews(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def list_reviews(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}/reviews", opts)
  end

  @doc "Auto-paginates the reviews on a pull request into a lazy `Stream`."
  @spec stream_reviews(Client.t(), String.t(), String.t(), number_ref(), keyword()) ::
          Enumerable.t()
  def stream_reviews(client, owner, repo, number, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/pulls/#{number}/reviews", opts)
  end

  @doc "Creates a review on a pull request. `attrs` sets `event` (APPROVE, REQUEST_CHANGES, COMMENT), `body`, `comments`."
  @spec create_review(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) ::
          REST.result()
  def create_review(client, owner, repo, number, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/reviews",
      Keyword.put(opts, :json, attrs)
    )
  end

  defp with_accept(opts, media_type) do
    Keyword.update(opts, :headers, [{"accept", media_type}], fn headers ->
      [{"accept", media_type} | Enum.reject(headers, &accept_header?/1)]
    end)
  end

  defp accept_header?({name, _value}), do: name |> to_string() |> String.downcase() == "accept"
end
