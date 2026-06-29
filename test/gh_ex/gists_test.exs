defmodule GhEx.GistsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/1 GETs gists for the authenticated user" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.request_path == "/gists"
      Req.Test.json(conn, [%{"id" => "abc"}])
    end)

    assert {:ok, [%{"id" => "abc"}], _} = GhEx.Gists.list(client(__MODULE__.List))
  end

  test "get/2 GETs a gist by id" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/gists/abc123"
      Req.Test.json(conn, %{"id" => "abc123"})
    end)

    assert {:ok, %{"id" => "abc123"}, _} = GhEx.Gists.get(client(__MODULE__.Get), "abc123")
  end

  test "create/2 POSTs a new gist" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gists"
      assert body(conn) == %{"public" => true}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => "xyz"})
    end)

    assert {:ok, %{"id" => "xyz"}, _} =
             GhEx.Gists.create(client(__MODULE__.Create), %{public: true})
  end

  test "update/3 PATCHes a gist" do
    Req.Test.stub(__MODULE__.Update, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/gists/abc123"
      assert body(conn) == %{"description" => "new"}
      Req.Test.json(conn, %{"id" => "abc123", "description" => "new"})
    end)

    assert {:ok, %{"id" => "abc123"}, _} =
             GhEx.Gists.update(client(__MODULE__.Update), "abc123", %{description: "new"})
  end

  test "delete/2 DELETEs a gist" do
    Req.Test.stub(__MODULE__.Delete, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/gists/abc123"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} = GhEx.Gists.delete(client(__MODULE__.Delete), "abc123")
    assert meta.status == 204
  end

  test "stream/2 auto-paginates the user's gists" do
    Req.Test.stub(__MODULE__.Stream, fn conn ->
      assert conn.request_path == "/gists"
      Req.Test.json(conn, [%{"id" => "abc"}])
    end)

    assert client(__MODULE__.Stream) |> GhEx.Gists.stream() |> Enum.to_list() == [
             %{"id" => "abc"}
           ]
  end
end
