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

  test "list_run_jobs/4 GETs run jobs" do
    Req.Test.stub(__MODULE__.Jobs, fn conn ->
      assert conn.request_path == "/repos/o/r/actions/runs/9/jobs"
      Req.Test.json(conn, %{"total_count" => 2})
    end)

    assert {:ok, %{"total_count" => 2}, _} =
             GhEx.Actions.list_run_jobs(client(__MODULE__.Jobs), "o", "r", 9)
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
end
