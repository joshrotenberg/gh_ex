defmodule GhEx.Releases do
  @moduledoc """
  Convenience functions for the GitHub Releases REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @type id :: integer() | String.t()

  @doc "Lists releases for a repository."
  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases", opts)
  end

  @doc "Auto-paginates a repository's releases into a lazy `Stream` (see `GhEx.REST.stream/3`)."
  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/releases", opts)
  end

  @doc "Gets a release by id."
  @spec get(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get(client, owner, repo, id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases/#{id}", opts)
  end

  @doc "Gets the latest published release."
  @spec get_latest(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_latest(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases/latest", opts)
  end

  @doc "Gets a release by tag name."
  @spec get_by_tag(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_by_tag(client, owner, repo, tag, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases/tags/#{tag}", opts)
  end

  @doc "Creates a release. `attrs` is the JSON body (tag_name, name, body, draft, prerelease, ...)."
  @spec create(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/releases", Keyword.put(opts, :json, attrs))
  end

  @doc "Updates a release."
  @spec update(Client.t(), String.t(), String.t(), id(), map(), keyword()) :: REST.result()
  def update(client, owner, repo, id, attrs, opts \\ []) do
    REST.patch(client, "/repos/#{owner}/#{repo}/releases/#{id}", Keyword.put(opts, :json, attrs))
  end

  @doc "Deletes a release."
  @spec delete(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def delete(client, owner, repo, id, opts \\ []) do
    REST.delete(client, "/repos/#{owner}/#{repo}/releases/#{id}", opts)
  end
end
