defmodule GhEx.Actions do
  @moduledoc """
  Convenience functions for the GitHub Actions REST API (workflows and runs).

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`. A `workflow` is the
  numeric workflow id or its file name (for example `"ci.yml"`).
  """

  alias GhEx.{Client, REST}

  @type id :: integer() | String.t()

  @doc "Lists the workflows in a repository."
  @spec list_workflows(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_workflows(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/workflows", opts)
  end

  @doc """
  Auto-paginates the workflows in a repository into a lazy `Stream`, unwrapping
  the `"workflows"` array on each page (see `GhEx.REST.stream/3`).
  """
  @spec stream_workflows(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_workflows(client, owner, repo, opts \\ []) do
    REST.stream(
      client,
      "/repos/#{owner}/#{repo}/actions/workflows",
      Keyword.put(opts, :items, "workflows")
    )
  end

  @doc "Gets a workflow by id or file name."
  @spec get_workflow(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get_workflow(client, owner, repo, workflow, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/workflows/#{workflow}", opts)
  end

  @doc """
  Triggers a `workflow_dispatch` event. `attrs` is the JSON body: `ref` (required)
  and optional `inputs`. Returns a `204` with an empty body on success.
  """
  @spec dispatch_workflow(Client.t(), String.t(), String.t(), id(), map(), keyword()) ::
          REST.result()
  def dispatch_workflow(client, owner, repo, workflow, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/actions/workflows/#{workflow}/dispatches",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Lists workflow runs in a repository. Use `params:` for `branch`, `status`, `event`."
  @spec list_runs(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_runs(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/runs", opts)
  end

  @doc "Auto-paginates workflow runs into a lazy `Stream`, unwrapping `\"workflow_runs\"`."
  @spec stream_runs(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_runs(client, owner, repo, opts \\ []) do
    REST.stream(
      client,
      "/repos/#{owner}/#{repo}/actions/runs",
      Keyword.put(opts, :items, "workflow_runs")
    )
  end

  @doc "Gets a workflow run."
  @spec get_run(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get_run(client, owner, repo, run_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}", opts)
  end

  @doc "Lists the jobs for a workflow run."
  @spec list_run_jobs(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def list_run_jobs(client, owner, repo, run_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/jobs", opts)
  end

  @doc "Auto-paginates the jobs for a workflow run into a lazy `Stream`, unwrapping `\"jobs\"`."
  @spec stream_run_jobs(Client.t(), String.t(), String.t(), id(), keyword()) :: Enumerable.t()
  def stream_run_jobs(client, owner, repo, run_id, opts \\ []) do
    REST.stream(
      client,
      "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/jobs",
      Keyword.put(opts, :items, "jobs")
    )
  end

  @doc "Cancels a workflow run."
  @spec cancel_run(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def cancel_run(client, owner, repo, run_id, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/cancel", opts)
  end

  @doc "Re-runs a workflow run."
  @spec rerun(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def rerun(client, owner, repo, run_id, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/rerun", opts)
  end
end
