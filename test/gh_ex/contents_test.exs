defmodule GhEx.ContentsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "get/4 GETs file contents with a ref" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/repos/o/r/contents/lib/app.ex"
      assert conn.query_string == "ref=main"
      Req.Test.json(conn, %{"path" => "lib/app.ex", "encoding" => "base64"})
    end)

    assert {:ok, %{"path" => "lib/app.ex"}, _} =
             GhEx.Contents.get(client(__MODULE__.Get), "o", "r", "lib/app.ex",
               params: [ref: "main"]
             )
  end

  test "create_or_update_file/5 PUTs the body" do
    Req.Test.stub(__MODULE__.Put, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/repos/o/r/contents/README.md"
      assert body(conn) == %{"message" => "docs", "content" => "aGk="}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"commit" => %{"sha" => "abc"}})
    end)

    assert {:ok, %{"commit" => _}, _} =
             GhEx.Contents.create_or_update_file(
               client(__MODULE__.Put),
               "o",
               "r",
               "README.md",
               %{message: "docs", content: Base.encode64("hi")}
             )
  end

  test "delete_file/5 DELETEs with a body" do
    Req.Test.stub(__MODULE__.Delete, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/o/r/contents/old.txt"
      assert body(conn) == %{"message" => "rm", "sha" => "deadbeef"}
      Req.Test.json(conn, %{"commit" => %{"sha" => "xyz"}})
    end)

    assert {:ok, %{"commit" => _}, _} =
             GhEx.Contents.delete_file(
               client(__MODULE__.Delete),
               "o",
               "r",
               "old.txt",
               %{message: "rm", sha: "deadbeef"}
             )
  end
end
