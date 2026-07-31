defmodule GhEx.ActionsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list_workflows/3 GETs workflows" do
    Req.Test.stub(__MODULE__.Workflows, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/workflows"
      Req.Test.json(conn, %{"total_count" => 1})
    end)

    assert {:ok, %{"total_count" => 1}, _} =
             GhEx.Actions.list_workflows(client(__MODULE__.Workflows), "o", "r")
  end

  test "get_workflow/4 accepts a file name" do
    Req.Test.stub(__MODULE__.Workflow, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/workflows/ci.yml"
      Req.Test.json(conn, %{"name" => "CI"})
    end)

    assert {:ok, %{"name" => "CI"}, _} =
             GhEx.Actions.get_workflow(client(__MODULE__.Workflow), "o", "r", "ci.yml")
  end

  test "dispatch_workflow/5 POSTs ref/inputs and handles a 204" do
    Req.Test.stub(__MODULE__.Dispatch, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/actions/workflows/ci.yml/dispatches"
      assert body(conn) == %{"ref" => "main", "inputs" => %{"k" => "v"}}
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Actions.dispatch_workflow(client(__MODULE__.Dispatch), "o", "r", "ci.yml", %{
               ref: "main",
               inputs: %{k: "v"}
             })

    assert meta.status == 204
  end

  test "list_artifacts/3 GETs repository artifacts" do
    Req.Test.stub(__MODULE__.Artifacts, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/artifacts"
      assert conn.query_string == "name=coverage"
      Req.Test.json(conn, %{"total_count" => 1, "artifacts" => [%{"id" => 11}]})
    end)

    assert {:ok, %{"total_count" => 1}, _} =
             GhEx.Actions.list_artifacts(client(__MODULE__.Artifacts), "o", "r",
               params: [name: "coverage"]
             )
  end

  test "get_artifact/4 GETs one artifact" do
    Req.Test.stub(__MODULE__.Artifact, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/artifacts/11"
      Req.Test.json(conn, %{"id" => 11, "name" => "coverage"})
    end)

    assert {:ok, %{"id" => 11}, _} =
             GhEx.Actions.get_artifact(client(__MODULE__.Artifact), "o", "r", 11)
  end

  test "download_artifact/5 follows the redirect, returns bytes, and strips cross-origin auth" do
    archive = <<0x50, 0x4B, 0x03, 0x04, 0x00, 0xFF>>

    Req.Test.stub(__MODULE__.DownloadArtifact, fn conn ->
      case conn.request_path do
        "/repos/o/r/actions/artifacts/11/zip" ->
          assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer t"]
          Req.Test.redirect(conn, external: "https://downloads.example.test/artifact.zip")

        "/artifact.zip" ->
          assert conn.host == "downloads.example.test"
          assert Plug.Conn.get_req_header(conn, "authorization") == []

          conn
          |> Plug.Conn.put_resp_content_type("application/zip")
          |> Plug.Conn.send_resp(200, archive)
      end
    end)

    assert {:ok, ^archive, meta} =
             GhEx.Actions.download_artifact(
               client(__MODULE__.DownloadArtifact),
               "o",
               "r",
               11,
               "zip"
             )

    assert meta.status == 200
  end

  test "delete_artifact/4 DELETEs one artifact" do
    Req.Test.stub(__MODULE__.DeleteArtifact, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/o/r/actions/artifacts/11"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Actions.delete_artifact(client(__MODULE__.DeleteArtifact), "o", "r", 11)

    assert meta.status == 204
  end

  test "list_runs/3 GETs runs with params" do
    Req.Test.stub(__MODULE__.Runs, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs"
      assert conn.query_string == "status=success"
      Req.Test.json(conn, %{"total_count" => 0})
    end)

    assert {:ok, %{"total_count" => 0}, _} =
             GhEx.Actions.list_runs(client(__MODULE__.Runs), "o", "r",
               params: [status: "success"]
             )
  end

  test "get_run/4 GETs a run" do
    Req.Test.stub(__MODULE__.Run, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs/9"
      Req.Test.json(conn, %{"id" => 9})
    end)

    assert {:ok, %{"id" => 9}, _} = GhEx.Actions.get_run(client(__MODULE__.Run), "o", "r", 9)
  end

  test "list_run_artifacts/4 GETs artifacts for one run" do
    Req.Test.stub(__MODULE__.RunArtifacts, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs/9/artifacts"
      Req.Test.json(conn, %{"total_count" => 1, "artifacts" => [%{"id" => 11}]})
    end)

    assert {:ok, %{"total_count" => 1}, _} =
             GhEx.Actions.list_run_artifacts(client(__MODULE__.RunArtifacts), "o", "r", 9)
  end

  test "download_run_logs/4 GETs and returns the run log archive bytes" do
    archive = <<0x50, 0x4B, 0x03, 0x04>>

    Req.Test.stub(__MODULE__.RunLogs, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs/9/logs"

      conn
      |> Plug.Conn.put_resp_content_type("application/zip")
      |> Plug.Conn.send_resp(200, archive)
    end)

    assert {:ok, ^archive, _} =
             GhEx.Actions.download_run_logs(client(__MODULE__.RunLogs), "o", "r", 9)
  end

  test "delete_run_logs/4 DELETEs all logs for a run" do
    Req.Test.stub(__MODULE__.DeleteRunLogs, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/o/r/actions/runs/9/logs"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Actions.delete_run_logs(client(__MODULE__.DeleteRunLogs), "o", "r", 9)

    assert meta.status == 204
  end

  test "list_run_jobs/4 GETs run jobs" do
    Req.Test.stub(__MODULE__.Jobs, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs/9/jobs"
      Req.Test.json(conn, %{"total_count" => 2})
    end)

    assert {:ok, %{"total_count" => 2}, _} =
             GhEx.Actions.list_run_jobs(client(__MODULE__.Jobs), "o", "r", 9)
  end

  test "get_job/4 GETs one workflow job" do
    Req.Test.stub(__MODULE__.Job, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/jobs/3"
      Req.Test.json(conn, %{"id" => 3, "name" => "test"})
    end)

    assert {:ok, %{"id" => 3}, _} = GhEx.Actions.get_job(client(__MODULE__.Job), "o", "r", 3)
  end

  test "download_job_logs/4 GETs and returns plain-text job logs" do
    logs = "2026-07-31T00:00:00Z test passed\n"

    Req.Test.stub(__MODULE__.JobLogs, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/jobs/3/logs"
      Req.Test.text(conn, logs)
    end)

    assert {:ok, ^logs, _} =
             GhEx.Actions.download_job_logs(client(__MODULE__.JobLogs), "o", "r", 3)
  end

  test "cancel_run/4 POSTs to cancel" do
    Req.Test.stub(__MODULE__.Cancel, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/actions/runs/9/cancel"
      Plug.Conn.send_resp(conn, 202, "")
    end)

    assert {:ok, _body, meta} = GhEx.Actions.cancel_run(client(__MODULE__.Cancel), "o", "r", 9)
    assert meta.status == 202
  end

  test "rerun/4 POSTs to rerun" do
    Req.Test.stub(__MODULE__.Rerun, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/actions/runs/9/rerun"
      Plug.Conn.send_resp(conn, 201, "")
    end)

    assert {:ok, _body, meta} = GhEx.Actions.rerun(client(__MODULE__.Rerun), "o", "r", 9)
    assert meta.status == 201
  end

  test "rerun_job/4 POSTs optional debug settings" do
    Req.Test.stub(__MODULE__.RerunJob, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/actions/jobs/3/rerun"
      assert body(conn) == %{"enable_debugger" => true}
      Plug.Conn.send_resp(conn, 201, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Actions.rerun_job(client(__MODULE__.RerunJob), "o", "r", 3,
               json: %{enable_debugger: true}
             )

    assert meta.status == 201
  end

  test "rerun_failed_jobs/4 POSTs optional debug logging" do
    Req.Test.stub(__MODULE__.RerunFailed, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/actions/runs/9/rerun-failed-jobs"
      assert body(conn) == %{"enable_debug_logging" => true}
      Plug.Conn.send_resp(conn, 201, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Actions.rerun_failed_jobs(client(__MODULE__.RerunFailed), "o", "r", 9,
               json: %{enable_debug_logging: true}
             )

    assert meta.status == 201
  end

  test "stream_workflows/3 unwraps the workflows array" do
    Req.Test.stub(__MODULE__.StreamWorkflows, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/workflows"
      Req.Test.json(conn, %{"total_count" => 1, "workflows" => [%{"id" => 1}]})
    end)

    assert client(__MODULE__.StreamWorkflows)
           |> GhEx.Actions.stream_workflows("o", "r")
           |> Enum.to_list() == [%{"id" => 1}]
  end

  test "stream_runs/3 unwraps the workflow_runs array" do
    Req.Test.stub(__MODULE__.StreamRuns, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs"
      Req.Test.json(conn, %{"total_count" => 1, "workflow_runs" => [%{"id" => 7}]})
    end)

    assert client(__MODULE__.StreamRuns)
           |> GhEx.Actions.stream_runs("o", "r")
           |> Enum.to_list() == [%{"id" => 7}]
  end

  test "stream_run_jobs/4 unwraps the jobs array" do
    Req.Test.stub(__MODULE__.StreamRunJobs, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs/9/jobs"
      Req.Test.json(conn, %{"total_count" => 1, "jobs" => [%{"id" => 3}]})
    end)

    assert client(__MODULE__.StreamRunJobs)
           |> GhEx.Actions.stream_run_jobs("o", "r", 9)
           |> Enum.to_list() == [%{"id" => 3}]
  end

  test "stream_artifacts/3 unwraps the artifacts array" do
    Req.Test.stub(__MODULE__.StreamArtifacts, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/artifacts"
      Req.Test.json(conn, %{"total_count" => 1, "artifacts" => [%{"id" => 11}]})
    end)

    assert client(__MODULE__.StreamArtifacts)
           |> GhEx.Actions.stream_artifacts("o", "r")
           |> Enum.to_list() == [%{"id" => 11}]
  end

  test "stream_run_artifacts/4 unwraps the artifacts array" do
    Req.Test.stub(__MODULE__.StreamRunArtifacts, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs/9/artifacts"
      Req.Test.json(conn, %{"total_count" => 1, "artifacts" => [%{"id" => 11}]})
    end)

    assert client(__MODULE__.StreamRunArtifacts)
           |> GhEx.Actions.stream_run_artifacts("o", "r", 9)
           |> Enum.to_list() == [%{"id" => 11}]
  end
end
