defmodule GhEx.Teams do
  @moduledoc """
  Convenience functions for the GitHub Teams REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @doc "Lists teams in an organization."
  @spec list(Client.t(), String.t(), keyword()) :: REST.result()
  def list(client, org, opts \\ []) do
    REST.get(client, "/orgs/#{org}/teams", opts)
  end

  @doc "Auto-paginates an organization's teams into a lazy `Stream` (see `GhEx.REST.stream/3`)."
  @spec stream(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, org, opts \\ []) do
    REST.stream(client, "/orgs/#{org}/teams", opts)
  end

  @doc "Gets a team by slug."
  @spec get_by_slug(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_by_slug(client, org, slug, opts \\ []) do
    REST.get(client, "/orgs/#{org}/teams/#{slug}", opts)
  end

  @doc "Creates a team in an organization. `attrs` is the JSON body (name, description, ...)."
  @spec create(Client.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, org, attrs, opts \\ []) do
    REST.post(client, "/orgs/#{org}/teams", Keyword.put(opts, :json, attrs))
  end

  @doc "Lists members of a team."
  @spec list_members(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_members(client, org, slug, opts \\ []) do
    REST.get(client, "/orgs/#{org}/teams/#{slug}/members", opts)
  end

  @doc "Auto-paginates a team's members into a lazy `Stream`."
  @spec stream_members(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_members(client, org, slug, opts \\ []) do
    REST.stream(client, "/orgs/#{org}/teams/#{slug}/members", opts)
  end
end
