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

  test "upload_asset/5 POSTs raw bytes to the GitHub.com upload origin" do
    data = <<0x50, 0x4B, 0x03, 0x04, 0xFF>>

    Req.Test.stub(__MODULE__.UploadAsset, fn conn ->
      assert conn.method == "POST"
      assert conn.host == "uploads.github.com"
      assert conn.request_path == "/repos/o/r/releases/42/assets"

      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"label" => "Linux archive", "name" => "gh_ex.zip"}
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/zip"]
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer t"]
      assert {:ok, ^data, _conn} = Plug.Conn.read_body(conn)

      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(%{"id" => 7, "name" => "gh_ex.zip", "state" => "uploaded"})
    end)

    asset = %{
      name: "gh_ex.zip",
      label: "Linux archive",
      content_type: "application/zip",
      data: data
    }

    assert {:ok, %{"id" => 7, "state" => "uploaded"}, %{status: 201}} =
             GhEx.Releases.upload_asset(client(__MODULE__.UploadAsset), "o", "r", 42, asset)
  end

  test "upload_asset/5 derives the GHES api/uploads endpoint" do
    Req.Test.stub(__MODULE__.UploadAssetGHES, fn conn ->
      assert conn.host == "ghe.example.test"
      assert conn.request_path == "/api/uploads/repos/o/r/releases/42/assets"
      assert conn.query_string == "name=gh_ex.tar.gz"
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/gzip"]
      Req.Test.json(Plug.Conn.put_status(conn, 201), %{"id" => 8})
    end)

    client =
      GhEx.new(
        auth: {:token, "t"},
        rest_url: "https://ghe.example.test/api/v3",
        req_options: [plug: {Req.Test, __MODULE__.UploadAssetGHES}]
      )

    asset = %{name: "gh_ex.tar.gz", content_type: "application/gzip", data: "archive"}

    assert {:ok, %{"id" => 8}, _} =
             GhEx.Releases.upload_asset(client, "o", "r", 42, asset)
  end

  test "upload_asset/6 accepts a templated hypermedia upload URL and owns upload fields" do
    Req.Test.stub(__MODULE__.UploadAssetURL, fn conn ->
      assert conn.host == "uploads.example.test"
      assert conn.request_path == "/custom/releases/42/assets"

      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params == %{"keep" => "yes", "name" => "release.bin"}
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/octet-stream"]
      assert {:ok, "raw", _conn} = Plug.Conn.read_body(conn)
      Req.Test.json(Plug.Conn.put_status(conn, 201), %{"id" => 9})
    end)

    asset = %{name: "release.bin", content_type: "application/octet-stream", data: "raw"}

    assert {:ok, %{"id" => 9}, _} =
             GhEx.Releases.upload_asset(client(__MODULE__.UploadAssetURL), "o", "r", 42, asset,
               upload_url: "https://uploads.example.test/custom/releases/42/assets{?name,label}",
               params: [name: "wrong", label: "wrong", keep: "yes"],
               headers: [{"content-type", "text/plain"}],
               json: %{wrong: true}
             )
  end

  test "generate_release_notes/4 POSTs note-generation inputs" do
    Req.Test.stub(__MODULE__.GenerateNotes, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/releases/generate-notes"

      assert body(conn) == %{
               "tag_name" => "v1.0.0",
               "target_commitish" => "main",
               "previous_tag_name" => "v0.9.0"
             }

      Req.Test.json(conn, %{"name" => "v1.0.0", "body" => "Changes"})
    end)

    attrs = %{tag_name: "v1.0.0", target_commitish: "main", previous_tag_name: "v0.9.0"}

    assert {:ok, %{"name" => "v1.0.0", "body" => "Changes"}, _} =
             GhEx.Releases.generate_release_notes(
               client(__MODULE__.GenerateNotes),
               "o",
               "r",
               attrs
             )
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
