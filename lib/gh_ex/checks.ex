defmodule GhEx.Checks do
  @moduledoc """
  Convenience functions for the GitHub Checks REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, Error, REST}

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

  @doc """
  Finds a GitHub App's check run with `check_name` on a git ref.

  Returns `{:ok, run, meta}` for the first run GitHub returns, or
  `{:ok, nil, meta}` when none matches. GitHub defaults the endpoint to its
  `latest` filter. This function only performs the lookup; the caller decides
  whether to call `create_run/5` or `update_run/6` next.

  `app_id` is the numeric GitHub App ID, not an installation ID or OAuth client
  ID. Reuse the numeric ID passed when building the app client described by
  `GhEx.App`, or authenticate as the app and read it from:

      {:ok, %{"id" => app_id}, _meta} = GhEx.REST.get(app_client, "/app")

  Caller-supplied query parameters are preserved, but `check_name` and `app_id`
  are always set from their explicit arguments.
  """
  @spec find_run_for_ref(
          Client.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          integer() | String.t(),
          keyword()
        ) :: REST.result()
  def find_run_for_ref(client, owner, repo, ref, check_name, app_id, opts \\ []) do
    path = "/repos/#{owner}/#{repo}/commits/#{encode_segment(ref)}/check-runs"

    case REST.get(client, path, with_lookup_params(opts, check_name, app_id)) do
      {:ok, %{"check_runs" => [run | _]}, meta} ->
        {:ok, run, meta}

      {:ok, %{"check_runs" => []}, meta} ->
        {:ok, nil, meta}

      {:ok, body, _meta} ->
        {:error,
         %Error{
           message: "check-runs response did not contain a check_runs array",
           body: body
         }}

      {:error, _reason} = error ->
        error
    end
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

  defp with_lookup_params(opts, check_name, app_id) do
    params =
      opts
      |> Keyword.get(:params, %{})
      |> Map.new()
      |> Map.drop([:check_name, "check_name", :app_id, "app_id"])
      |> Map.merge(%{check_name: check_name, app_id: app_id})

    Keyword.put(opts, :params, params)
  end

  defp encode_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
