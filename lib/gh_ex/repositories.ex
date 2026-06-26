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

  @doc "Lists public repositories for a user."
  @spec list_for_user(Client.t(), String.t(), keyword()) :: REST.result()
  def list_for_user(client, username, opts \\ []) do
    REST.get(client, "/users/#{username}/repos", opts)
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

  @doc "Lists commits on a repository. Use `params:` for `sha`, `path`, `since`, `until`."
  @spec list_commits(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_commits(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits", opts)
  end

  @doc "Lists branches on a repository."
  @spec list_branches(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_branches(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/branches", opts)
  end
end
