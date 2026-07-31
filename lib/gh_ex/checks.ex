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

  @doc "Lists the annotations attached to a check run."
  @spec list_annotations(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def list_annotations(client, owner, repo, check_run_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/check-runs/#{check_run_id}/annotations", opts)
  end

  @doc "Auto-paginates a check run's annotations into a lazy `Stream`."
  @spec stream_annotations(Client.t(), String.t(), String.t(), id(), keyword()) ::
          Enumerable.t()
  def stream_annotations(client, owner, repo, check_run_id, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/check-runs/#{check_run_id}/annotations", opts)
  end

  @doc """
  Rerequests a check run without pushing new code.

  GitHub resets the containing check suite and emits a `check_run` webhook with
  the `rerequested` action. The app that owns the run must handle that webhook
  and update the check run as needed. This is separate from rerunning a GitHub
  Actions workflow through `GhEx.Actions` and requires Checks write permission.
  """
  @spec rerequest_run(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def rerequest_run(client, owner, repo, check_run_id, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/check-runs/#{check_run_id}/rerequest", opts)
  end

  @doc "Lists check runs for a git ref."
  @spec list_for_ref(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_for_ref(client, owner, repo, ref, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits/#{ref}/check-runs", opts)
  end

  @doc """
  Auto-paginates the check runs for a git ref into a lazy `Stream`, unwrapping
  the `"check_runs"` array on each page (see `GhEx.REST.stream/3`).
  """
  @spec stream_for_ref(Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          Enumerable.t()
  def stream_for_ref(client, owner, repo, ref, opts \\ []) do
    REST.stream(
      client,
      "/repos/#{owner}/#{repo}/commits/#{ref}/check-runs",
      Keyword.put(opts, :items, "check_runs")
    )
  end
end
