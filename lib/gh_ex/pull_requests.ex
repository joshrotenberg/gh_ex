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
end
