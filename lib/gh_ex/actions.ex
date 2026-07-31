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

  @doc "Lists all Actions artifacts in a repository. Use `params: [name: ...]` to filter."
  @spec list_artifacts(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_artifacts(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/artifacts", opts)
  end

  @doc "Auto-paginates repository artifacts into a lazy `Stream`, unwrapping `\"artifacts\"`."
  @spec stream_artifacts(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_artifacts(client, owner, repo, opts \\ []) do
    REST.stream(
      client,
      "/repos/#{owner}/#{repo}/actions/artifacts",
      Keyword.put(opts, :items, "artifacts")
    )
  end

  @doc "Gets one Actions artifact by id."
  @spec get_artifact(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get_artifact(client, owner, repo, artifact_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/artifacts/#{artifact_id}", opts)
  end

  @doc """
  Downloads an artifact archive and returns `{:ok, bytes, meta}`.

  GitHub currently supports only the `"zip"` archive format. Req follows the
  temporary signed-URL redirect automatically and does not forward credentials
  when the redirect changes origin. The returned `meta` describes the final
  download response.
  """
  @spec download_artifact(
          Client.t(),
          String.t(),
          String.t(),
          id(),
          String.t(),
          keyword()
        ) :: REST.result()
  def download_artifact(client, owner, repo, artifact_id, archive_format, opts \\ []) do
    REST.get(
      client,
      "/repos/#{owner}/#{repo}/actions/artifacts/#{artifact_id}/#{archive_format}",
      opts
    )
  end

  @doc "Deletes an Actions artifact. GitHub returns `204 No Content` on success."
  @spec delete_artifact(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def delete_artifact(client, owner, repo, artifact_id, opts \\ []) do
    REST.delete(client, "/repos/#{owner}/#{repo}/actions/artifacts/#{artifact_id}", opts)
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

  @doc "Lists the artifacts produced by one workflow run."
  @spec list_run_artifacts(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def list_run_artifacts(client, owner, repo, run_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/artifacts", opts)
  end

  @doc "Auto-paginates one workflow run's artifacts, unwrapping `\"artifacts\"`."
  @spec stream_run_artifacts(Client.t(), String.t(), String.t(), id(), keyword()) ::
          Enumerable.t()
  def stream_run_artifacts(client, owner, repo, run_id, opts \\ []) do
    REST.stream(
      client,
      "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/artifacts",
      Keyword.put(opts, :items, "artifacts")
    )
  end

  @doc """
  Downloads a workflow run's log archive and returns `{:ok, zip_bytes, meta}`.

  Req follows GitHub's temporary signed-URL redirect automatically and strips
  credentials if the redirect changes origin.
  """
  @spec download_run_logs(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def download_run_logs(client, owner, repo, run_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/logs", opts)
  end

  @doc "Deletes all logs for a workflow run. GitHub returns `204 No Content` on success."
  @spec delete_run_logs(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def delete_run_logs(client, owner, repo, run_id, opts \\ []) do
    REST.delete(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/logs", opts)
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

  @doc "Gets one job from a workflow run."
  @spec get_job(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get_job(client, owner, repo, job_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/jobs/#{job_id}", opts)
  end

  @doc """
  Downloads one job's logs and returns `{:ok, text, meta}`.

  Req follows GitHub's temporary signed-URL redirect automatically and strips
  credentials if the redirect changes origin.
  """
  @spec download_job_logs(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def download_job_logs(client, owner, repo, job_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/actions/jobs/#{job_id}/logs", opts)
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

  @doc """
  Re-runs one job and its dependent jobs.

  Pass `json: %{enable_debug_logging: true}` or
  `json: %{enable_debugger: true}` in `opts` when needed.
  """
  @spec rerun_job(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def rerun_job(client, owner, repo, job_id, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/actions/jobs/#{job_id}/rerun", opts)
  end

  @doc """
  Re-runs failed jobs and their dependent jobs in a workflow run.

  Pass `json: %{enable_debug_logging: true}` in `opts` to enable debug logging.
  """
  @spec rerun_failed_jobs(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def rerun_failed_jobs(client, owner, repo, run_id, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/rerun-failed-jobs", opts)
  end
end
