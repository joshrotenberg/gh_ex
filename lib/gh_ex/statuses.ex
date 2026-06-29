defmodule GhEx.Statuses do
  @moduledoc """
  Convenience functions for the GitHub commit statuses REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @doc "Creates a commit status."
  @spec create(Client.t(), String.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, sha, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/statuses/#{sha}", Keyword.put(opts, :json, attrs))
  end

  @doc "Lists statuses for a git ref."
  @spec list_for_ref(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_for_ref(client, owner, repo, ref, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits/#{ref}/statuses", opts)
  end

  @doc "Auto-paginates the statuses for a git ref into a lazy `Stream` (see `GhEx.REST.stream/3`)."
  @spec stream_for_ref(Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          Enumerable.t()
  def stream_for_ref(client, owner, repo, ref, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/commits/#{ref}/statuses", opts)
  end

  @doc "Gets the combined status for a git ref."
  @spec get_combined(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_combined(client, owner, repo, ref, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits/#{ref}/status", opts)
  end
end
