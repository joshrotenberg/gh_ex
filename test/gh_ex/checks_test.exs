defmodule GhEx.ChecksTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "create_run/4 POSTs a check run" do
    Req.Test.stub(__MODULE__.CreateRun, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/check-runs"
      assert body(conn) == %{"name" => "ci", "head_sha" => "abc"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 1})
    end)

    assert {:ok, %{"id" => 1}, _} =
             GhEx.Checks.create_run(client(__MODULE__.CreateRun), "o", "r", %{
               name: "ci",
               head_sha: "abc"
             })
  end

  test "get_run/4 GETs a check run by id" do
    Req.Test.stub(__MODULE__.GetRun, fn conn ->
      assert conn.request_path == "/repos/o/r/check-runs/42"
      Req.Test.json(conn, %{"id" => 42})
    end)

    assert {:ok, %{"id" => 42}, _} =
             GhEx.Checks.get_run(client(__MODULE__.GetRun), "o", "r", 42)
  end

  test "update_run/5 PATCHes a check run" do
    Req.Test.stub(__MODULE__.UpdateRun, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/o/r/check-runs/42"
      assert body(conn) == %{"status" => "completed"}
      Req.Test.json(conn, %{"id" => 42, "status" => "completed"})
    end)

    assert {:ok, %{"id" => 42}, _} =
             GhEx.Checks.update_run(client(__MODULE__.UpdateRun), "o", "r", 42, %{
               status: "completed"
             })
  end

  test "list_annotations/4 GETs annotations for a check run" do
    Req.Test.stub(__MODULE__.ListAnnotations, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/check-runs/42/annotations"
      assert conn.query_string == "per_page=50"
      Req.Test.json(conn, [%{"path" => "lib/a.ex", "start_line" => 12}])
    end)

    assert {:ok, [%{"path" => "lib/a.ex"}], _} =
             GhEx.Checks.list_annotations(client(__MODULE__.ListAnnotations), "o", "r", 42,
               params: [per_page: 50]
             )
  end

  test "stream_annotations/4 auto-paginates check-run annotations" do
    Req.Test.stub(__MODULE__.StreamAnnotations, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/check-runs/42/annotations"
      Req.Test.json(conn, [%{"path" => "lib/a.ex", "annotation_level" => "failure"}])
    end)

    assert client(__MODULE__.StreamAnnotations)
           |> GhEx.Checks.stream_annotations("o", "r", 42)
           |> Enum.to_list() == [%{"path" => "lib/a.ex", "annotation_level" => "failure"}]
  end

  test "rerequest_run/4 POSTs without a request body" do
    Req.Test.stub(__MODULE__.RerequestRun, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/check-runs/42/rerequest"
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert raw == ""
      Plug.Conn.send_resp(conn, 201, "")
    end)

    assert {:ok, response, %{status: 201}} =
             GhEx.Checks.rerequest_run(client(__MODULE__.RerequestRun), "o", "r", 42)

    assert response in ["", nil]
  end

  test "list_for_ref/4 GETs check runs for a ref" do
    Req.Test.stub(__MODULE__.ListForRef, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/main/check-runs"
      Req.Test.json(conn, %{"check_runs" => []})
    end)

    assert {:ok, %{"check_runs" => []}, _} =
             GhEx.Checks.list_for_ref(client(__MODULE__.ListForRef), "o", "r", "main")
  end

  test "stream_for_ref/5 unwraps the check_runs array" do
    Req.Test.stub(__MODULE__.StreamForRef, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/main/check-runs"
      Req.Test.json(conn, %{"total_count" => 1, "check_runs" => [%{"id" => 1}]})
    end)

    assert client(__MODULE__.StreamForRef)
           |> GhEx.Checks.stream_for_ref("o", "r", "main")
           |> Enum.to_list() == [%{"id" => 1}]
  end
end
