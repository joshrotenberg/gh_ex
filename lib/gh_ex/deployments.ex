defmodule GhEx.Deployments do
  @moduledoc """
  Convenience functions for the GitHub Deployments REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.

  A deployment represents a request to deploy a ref, not its changing lifecycle
  state. Progress is recorded as a sequence of deployment statuses. Automation
  waiting for completion should inspect the latest item from `list_statuses/5`
  (or consume `stream_statuses/5`) rather than repeatedly fetching the deployment.
  """

  alias GhEx.{Client, REST}

  @type id :: integer() | String.t()

  @doc "Lists deployments in a repository. Use `params:` to filter by ref, SHA, task, or environment."
  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/deployments", opts)
  end

  @doc "Auto-paginates a repository's deployments into a lazy `Stream`."
  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/deployments", opts)
  end

  @doc "Gets a deployment by id. Read its statuses to observe lifecycle progress."
  @spec get(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get(client, owner, repo, deployment_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/deployments/#{deployment_id}", opts)
  end

  @doc """
  Creates a deployment for a ref.

  `attrs` must contain `ref`; it may also include `task`, `auto_merge`,
  `required_contexts`, `payload`, `environment`, and environment metadata.
  """
  @spec create(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/deployments", Keyword.put(opts, :json, attrs))
  end

  @doc """
  Lists the status history for a deployment.

  Deployment progress is represented by these status records; inspect the latest
  record when deciding whether a deployment has reached a terminal state.
  """
  @spec list_statuses(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def list_statuses(client, owner, repo, deployment_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/deployments/#{deployment_id}/statuses", opts)
  end

  @doc "Auto-paginates a deployment's status history into a lazy `Stream`."
  @spec stream_statuses(Client.t(), String.t(), String.t(), id(), keyword()) :: Enumerable.t()
  def stream_statuses(client, owner, repo, deployment_id, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/deployments/#{deployment_id}/statuses", opts)
  end

  @doc """
  Appends a status to a deployment.

  `attrs` must contain `state`; supported states include `error`, `failure`,
  `inactive`, `in_progress`, `queued`, `pending`, and `success`.
  """
  @spec create_status(Client.t(), String.t(), String.t(), id(), map(), keyword()) :: REST.result()
  def create_status(client, owner, repo, deployment_id, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/deployments/#{deployment_id}/statuses",
      Keyword.put(opts, :json, attrs)
    )
  end
end
