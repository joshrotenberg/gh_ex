defmodule GhEx.Organizations do
  @moduledoc """
  Convenience functions for the GitHub Organizations REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @doc "Gets an organization."
  @spec get(Client.t(), String.t(), keyword()) :: REST.result()
  def get(client, org, opts \\ []) do
    REST.get(client, "/orgs/#{org}", opts)
  end

  @doc "Lists organizations for the authenticated user."
  @spec list_for_authenticated_user(Client.t(), keyword()) :: REST.result()
  def list_for_authenticated_user(client, opts \\ []) do
    REST.get(client, "/user/orgs", opts)
  end

  @doc "Updates an organization. `attrs` is the JSON body."
  @spec update(Client.t(), String.t(), map(), keyword()) :: REST.result()
  def update(client, org, attrs, opts \\ []) do
    REST.patch(client, "/orgs/#{org}", Keyword.put(opts, :json, attrs))
  end

  @doc "Lists members of an organization."
  @spec list_members(Client.t(), String.t(), keyword()) :: REST.result()
  def list_members(client, org, opts \\ []) do
    REST.get(client, "/orgs/#{org}/members", opts)
  end
end
