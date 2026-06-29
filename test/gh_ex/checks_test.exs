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
