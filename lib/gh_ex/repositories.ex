defmodule GhEx.Repositories do
  @moduledoc """
  Convenience functions for the GitHub Repositories REST API.

  Thin wrappers over `GhEx.REST` that fill in the endpoint path and return the
  same `{:ok, body, meta}` / `{:error, reason}` shape; `opts` pass through to
  `Req` (so `:params`, headers, and a `Req.Test` plug all work). For an endpoint
  without a wrapper, call `GhEx.REST` directly.
  """

  alias GhEx.{Client, REST}

  @doc "Gets a repository."
  @spec get(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}", opts)
  end

  @doc "Lists repositories for an organization. Use `params:` for `type`, `sort`, `per_page`."
  @spec list_for_org(Client.t(), String.t(), keyword()) :: REST.result()
  def list_for_org(client, org, opts \\ []) do
    REST.get(client, "/orgs/#{org}/repos", opts)
  end

  @doc "Auto-paginates an organization's repositories into a lazy `Stream`."
  @spec stream_for_org(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_for_org(client, org, opts \\ []) do
    REST.stream(client, "/orgs/#{org}/repos", opts)
  end

  @doc "Lists public repositories for a user."
  @spec list_for_user(Client.t(), String.t(), keyword()) :: REST.result()
  def list_for_user(client, username, opts \\ []) do
    REST.get(client, "/users/#{username}/repos", opts)
  end

  @doc "Auto-paginates a user's public repositories into a lazy `Stream`."
  @spec stream_for_user(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_for_user(client, username, opts \\ []) do
    REST.stream(client, "/users/#{username}/repos", opts)
  end

  @doc "Creates a repository in an organization. `attrs` is the JSON body (name, private, ...)."
  @spec create_in_org(Client.t(), String.t(), map(), keyword()) :: REST.result()
  def create_in_org(client, org, attrs, opts \\ []) do
    REST.post(client, "/orgs/#{org}/repos", Keyword.put(opts, :json, attrs))
  end

  @doc "Updates a repository."
  @spec update(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def update(client, owner, repo, attrs, opts \\ []) do
    REST.patch(client, "/repos/#{owner}/#{repo}", Keyword.put(opts, :json, attrs))
  end

  @doc "Deletes a repository."
  @spec delete(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def delete(client, owner, repo, opts \\ []) do
    REST.delete(client, "/repos/#{owner}/#{repo}", opts)
  end

  @doc """
  Checks whether `username` is a repository collaborator.

  Returns `{:ok, true, meta}` for GitHub's `204` collaborator response and
  `{:ok, false, meta}` for `404`. Other failures retain the usual
  `{:error, reason}` shape.
  """
  @spec is_collaborator(Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          REST.result()
  # GitHub's endpoint and issue #123 deliberately use the `is_collaborator` name.
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_collaborator(client, owner, repo, username, opts \\ []) do
    REST.present?(
      client,
      "/repos/#{owner}/#{repo}/collaborators/#{encode_segment(username)}",
      opts
    )
  end

  @doc """
  Gets a user's effective repository permission and role.

  The response includes the legacy base `"permission"`, the assigned
  `"role_name"` (including custom roles), and a nested `"user"` object.
  """
  @spec get_collaborator_permission(
          Client.t(),
          String.t(),
          String.t(),
          String.t(),
          keyword()
        ) :: REST.result()
  def get_collaborator_permission(client, owner, repo, username, opts \\ []) do
    REST.get(
      client,
      "/repos/#{owner}/#{repo}/collaborators/#{encode_segment(username)}/permission",
      opts
    )
  end

  @doc "Lists commits on a repository. Use `params:` for `sha`, `path`, `since`, `until`."
  @spec list_commits(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_commits(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits", opts)
  end

  @doc "Auto-paginates a repository's commits into a lazy `Stream`."
  @spec stream_commits(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_commits(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/commits", opts)
  end

  @doc "Lists branches on a repository."
  @spec list_branches(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_branches(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/branches", opts)
  end

  @doc "Auto-paginates a repository's branches into a lazy `Stream`."
  @spec stream_branches(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_branches(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/branches", opts)
  end

  @doc """
  Lists activity events for a repository.

  GitHub optimizes event feeds for conditional polling. Store `meta.etag` from a
  successful response and send it back with
  `headers: [{"if-none-match", etag}]`; an unchanged feed returns
  `{:ok, :not_modified, meta}` without consuming the primary rate limit. The
  current polling interval remains available in `meta.headers["x-poll-interval"]`.
  """
  @spec events(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def events(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/events", opts)
  end

  @doc """
  Auto-paginates a repository's activity events into a lazy `Stream`.

  Use `events/4` instead when implementing an ETag-conditional polling loop,
  because a stream yields events rather than response metadata.
  """
  @spec stream_events(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_events(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/events", opts)
  end

  defp encode_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
