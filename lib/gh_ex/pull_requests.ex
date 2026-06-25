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
  Merges a pull request. `attrs` may set `commit_title`, `commit_message`, and
  `merge_method` (`"merge"`, `"squash"`, or `"rebase"`).
  """
  @spec merge(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) :: REST.result()
  def merge(client, owner, repo, number, attrs \\ %{}, opts \\ []) do
    REST.put(
      client,
      "/repos/#{owner}/#{repo}/pulls/#{number}/merge",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Lists the files changed in a pull request."
  @spec list_files(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def list_files(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}/files", opts)
  end

  @doc "Lists the reviews on a pull request."
  @spec list_reviews(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def list_reviews(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/pulls/#{number}/reviews", opts)
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
