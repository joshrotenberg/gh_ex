defmodule GhEx.StatusesTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "create/5 POSTs a commit status" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/statuses/deadbeef"
      assert body(conn) == %{"state" => "success"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 1, "state" => "success"})
    end)

    assert {:ok, %{"state" => "success"}, _} =
             GhEx.Statuses.create(client(__MODULE__.Create), "o", "r", "deadbeef", %{
               state: "success"
             })
  end

  test "list_for_ref/4 GETs statuses for a ref" do
    Req.Test.stub(__MODULE__.ListForRef, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/main/statuses"
      Req.Test.json(conn, [%{"state" => "success"}])
    end)

    assert {:ok, [%{"state" => "success"}], _} =
             GhEx.Statuses.list_for_ref(client(__MODULE__.ListForRef), "o", "r", "main")
  end

  test "get_combined/4 GETs combined status for a ref" do
    Req.Test.stub(__MODULE__.GetCombined, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/main/status"
      Req.Test.json(conn, %{"state" => "success"})
    end)

    assert {:ok, %{"state" => "success"}, _} =
             GhEx.Statuses.get_combined(client(__MODULE__.GetCombined), "o", "r", "main")
  end
end
