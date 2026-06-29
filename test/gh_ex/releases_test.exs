defmodule GhEx.ReleasesTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/3 GETs releases" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.request_path == "/repos/o/r/releases"
      Req.Test.json(conn, [%{"id" => 1}])
    end)

    assert {:ok, [%{"id" => 1}], _} = GhEx.Releases.list(client(__MODULE__.List), "o", "r")
  end

  test "get/4 GETs a release by id" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/repos/o/r/releases/42"
      Req.Test.json(conn, %{"id" => 42})
    end)

    assert {:ok, %{"id" => 42}, _} = GhEx.Releases.get(client(__MODULE__.Get), "o", "r", 42)
  end

  test "get_latest/3 GETs the latest release" do
    Req.Test.stub(__MODULE__.Latest, fn conn ->
      assert conn.request_path == "/repos/o/r/releases/latest"
      Req.Test.json(conn, %{"tag_name" => "v1.0.0"})
    end)

    assert {:ok, %{"tag_name" => "v1.0.0"}, _} =
             GhEx.Releases.get_latest(client(__MODULE__.Latest), "o", "r")
  end

  test "get_by_tag/4 GETs a release by tag" do
    Req.Test.stub(__MODULE__.Tag, fn conn ->
      assert conn.request_path == "/repos/o/r/releases/tags/v1.0.0"
      Req.Test.json(conn, %{"tag_name" => "v1.0.0"})
    end)

    assert {:ok, %{"tag_name" => "v1.0.0"}, _} =
             GhEx.Releases.get_by_tag(client(__MODULE__.Tag), "o", "r", "v1.0.0")
  end

  test "create/4 POSTs the release body" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/releases"
      assert body(conn) == %{"tag_name" => "v1.0.0"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 1})
    end)

    assert {:ok, %{"id" => 1}, _} =
             GhEx.Releases.create(client(__MODULE__.Create), "o", "r", %{tag_name: "v1.0.0"})
  end

  test "update/5 PATCHes the release" do
    Req.Test.stub(__MODULE__.Update, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/o/r/releases/42"
      assert body(conn) == %{"draft" => false}
      Req.Test.json(conn, %{"id" => 42, "draft" => false})
    end)

    assert {:ok, %{"draft" => false}, _} =
             GhEx.Releases.update(client(__MODULE__.Update), "o", "r", 42, %{draft: false})
  end

  test "delete/4 DELETEs the release" do
    Req.Test.stub(__MODULE__.Delete, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/o/r/releases/42"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} = GhEx.Releases.delete(client(__MODULE__.Delete), "o", "r", 42)
    assert meta.status == 204
  end

  test "stream/3 auto-paginates repo releases" do
    Req.Test.stub(__MODULE__.Stream, fn conn ->
      assert conn.request_path == "/repos/o/r/releases"
      Req.Test.json(conn, [%{"id" => 1}])
    end)

    assert client(__MODULE__.Stream) |> GhEx.Releases.stream("o", "r") |> Enum.to_list() ==
             [%{"id" => 1}]
  end
end
