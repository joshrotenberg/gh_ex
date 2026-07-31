defmodule GhEx.GitTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "get_ref/4 uses the singular endpoint and accepts a fully qualified ref" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/git/ref/heads/feature%20one"
      Req.Test.json(conn, %{"ref" => "refs/heads/feature one"})
    end)

    assert {:ok, %{"ref" => "refs/heads/feature one"}, _} =
             GhEx.Git.get_ref(client(__MODULE__.Get), "o", "r", "refs/heads/feature one")
  end

  test "create_ref/4 uses the plural endpoint and qualifies a relative atom-key ref" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/git/refs"
      assert body(conn) == %{"ref" => "refs/heads/feature", "sha" => "abc123"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"ref" => "refs/heads/feature"})
    end)

    assert {:ok, %{"ref" => "refs/heads/feature"}, _} =
             GhEx.Git.create_ref(client(__MODULE__.Create), "o", "r", %{
               ref: "heads/feature",
               sha: "abc123"
             })
  end

  test "create_ref/4 preserves a fully qualified string-key ref and owns the JSON body" do
    Req.Test.stub(__MODULE__.CreateQualified, fn conn ->
      assert body(conn) == %{"ref" => "refs/tags/v1.0.0", "sha" => "abc123"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"ref" => "refs/tags/v1.0.0"})
    end)

    assert {:ok, %{"ref" => "refs/tags/v1.0.0"}, _} =
             GhEx.Git.create_ref(
               client(__MODULE__.CreateQualified),
               "o",
               "r",
               %{"ref" => "refs/tags/v1.0.0", "sha" => "abc123"},
               json: %{ref: "refs/heads/caller-override", sha: "wrong"}
             )
  end

  test "delete_ref/4 uses the plural endpoint and encodes reserved path characters" do
    Req.Test.stub(__MODULE__.Delete, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/o/r/git/refs/heads/feature%23one"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Git.delete_ref(client(__MODULE__.Delete), "o", "r", "heads/feature#one")

    assert meta.status == 204
  end
end
