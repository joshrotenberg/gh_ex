defmodule GhEx.Checks do
  @moduledoc """
  Convenience functions for the GitHub Checks REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @type id :: integer() | String.t()

  @doc "Creates a check run."
  @spec create_run(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create_run(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/check-runs", Keyword.put(opts, :json, attrs))
  end

  @doc "Gets a check run by id."
  @spec get_run(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get_run(client, owner, repo, check_run_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/check-runs/#{check_run_id}", opts)
  end

  @doc "Updates a check run."
  @spec update_run(Client.t(), String.t(), String.t(), id(), map(), keyword()) :: REST.result()
  def update_run(client, owner, repo, check_run_id, attrs, opts \\ []) do
    REST.patch(
      client,
      "/repos/#{owner}/#{repo}/check-runs/#{check_run_id}",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Lists check runs for a git ref."
  @spec list_for_ref(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_for_ref(client, owner, repo, ref, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits/#{ref}/check-runs", opts)
  end
end
