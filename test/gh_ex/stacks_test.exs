defmodule GhEx.StacksTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/3 GETs repository stacks and passes filters" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/stacks"
      assert conn.query_string == "pull_request=102"
      Req.Test.json(conn, [%{"number" => 42}])
    end)

    assert {:ok, [%{"number" => 42}], _} =
             GhEx.Stacks.list(client(__MODULE__.List), "o", "r", params: [pull_request: 102])
  end

  test "stream/3 auto-paginates repository stacks" do
    Req.Test.stub(__MODULE__.Stream, fn conn ->
      assert conn.request_path == "/repos/o/r/stacks"
      Req.Test.json(conn, [%{"number" => 42}])
    end)

    assert client(__MODULE__.Stream) |> GhEx.Stacks.stream("o", "r") |> Enum.to_list() ==
             [%{"number" => 42}]
  end

  test "get/4 GETs a stack by stack number" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/repos/o/r/stacks/42"
      Req.Test.json(conn, %{"number" => 42})
    end)

    assert {:ok, %{"number" => 42}, _} = GhEx.Stacks.get(client(__MODULE__.Get), "o", "r", 42)
  end

  test "create/4 POSTs pull request numbers in caller-provided order" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/stacks"
      assert body(conn) == %{"pull_requests" => [101, 102, 103]}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"number" => 42})
    end)

    assert {:ok, %{"number" => 42}, _} =
             GhEx.Stacks.create(client(__MODULE__.Create), "o", "r", %{
               pull_requests: [101, 102, 103]
             })
  end

  test "add/5 POSTs pull requests to the stack's add endpoint" do
    Req.Test.stub(__MODULE__.Add, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/stacks/42/add"
      assert body(conn) == %{"pull_requests" => [104]}
      Req.Test.json(conn, %{"number" => 42})
    end)

    assert {:ok, %{"number" => 42}, _} =
             GhEx.Stacks.add(client(__MODULE__.Add), "o", "r", 42, %{
               pull_requests: [104]
             })
  end

  test "unstack/4 POSTs without a body and handles a dissolved stack" do
    Req.Test.stub(__MODULE__.Unstack, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/stacks/42/unstack"
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert raw == ""
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, body, meta} = GhEx.Stacks.unstack(client(__MODULE__.Unstack), "o", "r", 42)
    assert body in ["", nil]
    assert meta.status == 204
  end
end
