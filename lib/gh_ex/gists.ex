defmodule GhEx.Gists do
  @moduledoc """
  Convenience functions for the GitHub Gists REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @type id :: integer() | String.t()

  @doc "Lists gists for the authenticated user."
  @spec list(Client.t(), keyword()) :: REST.result()
  def list(client, opts \\ []) do
    REST.get(client, "/gists", opts)
  end

  @doc "Auto-paginates the authenticated user's gists into a lazy `Stream` (see `GhEx.REST.stream/3`)."
  @spec stream(Client.t(), keyword()) :: Enumerable.t()
  def stream(client, opts \\ []) do
    REST.stream(client, "/gists", opts)
  end

  @doc "Gets a gist by id."
  @spec get(Client.t(), id(), keyword()) :: REST.result()
  def get(client, gist_id, opts \\ []) do
    REST.get(client, "/gists/#{gist_id}", opts)
  end

  @doc "Creates a gist. `attrs` is the JSON body (files, description, public, ...)."
  @spec create(Client.t(), map(), keyword()) :: REST.result()
  def create(client, attrs, opts \\ []) do
    REST.post(client, "/gists", Keyword.put(opts, :json, attrs))
  end

  @doc "Updates a gist."
  @spec update(Client.t(), id(), map(), keyword()) :: REST.result()
  def update(client, gist_id, attrs, opts \\ []) do
    REST.patch(client, "/gists/#{gist_id}", Keyword.put(opts, :json, attrs))
  end

  @doc "Deletes a gist."
  @spec delete(Client.t(), id(), keyword()) :: REST.result()
  def delete(client, gist_id, opts \\ []) do
    REST.delete(client, "/gists/#{gist_id}", opts)
  end
end
