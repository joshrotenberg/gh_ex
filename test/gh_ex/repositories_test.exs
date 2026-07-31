defmodule GhEx.RepositoriesTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "get/3 GETs the repository" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/repos/o/r"
      Req.Test.json(conn, %{"full_name" => "o/r"})
    end)

    assert {:ok, %{"full_name" => "o/r"}, _} =
             GhEx.Repositories.get(client(__MODULE__.Get), "o", "r")
  end

  test "list_for_org/3 GETs org repos with params" do
    Req.Test.stub(__MODULE__.Org, fn conn ->
      assert conn.request_path == "/orgs/acme/repos"
      assert conn.query_string == "type=public"
      Req.Test.json(conn, [%{"name" => "x"}])
    end)

    assert {:ok, [%{"name" => "x"}], _} =
             GhEx.Repositories.list_for_org(client(__MODULE__.Org), "acme",
               params: [type: "public"]
             )
  end

  test "list_for_user/3 GETs user repos" do
    Req.Test.stub(__MODULE__.User, fn conn ->
      assert conn.request_path == "/users/josh/repos"
      Req.Test.json(conn, [])
    end)

    assert {:ok, [], _} = GhEx.Repositories.list_for_user(client(__MODULE__.User), "josh")
  end

  test "create_in_org/4 POSTs the repo body" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/orgs/acme/repos"
      assert body(conn) == %{"name" => "new"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"name" => "new"})
    end)

    assert {:ok, %{"name" => "new"}, _} =
             GhEx.Repositories.create_in_org(client(__MODULE__.Create), "acme", %{name: "new"})
  end

  test "update/4 PATCHes the repository" do
    Req.Test.stub(__MODULE__.Update, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/o/r"
      assert body(conn) == %{"private" => true}
      Req.Test.json(conn, %{"private" => true})
    end)

    assert {:ok, %{"private" => true}, _} =
             GhEx.Repositories.update(client(__MODULE__.Update), "o", "r", %{private: true})
  end

  test "delete/3 DELETEs the repository" do
    Req.Test.stub(__MODULE__.Delete, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/o/r"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} = GhEx.Repositories.delete(client(__MODULE__.Delete), "o", "r")
    assert meta.status == 204
  end

  test "is_collaborator/4 returns true for GitHub's 204 response" do
    Req.Test.stub(__MODULE__.IsCollaborator, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/collaborators/octocat"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, true, %{status: 204}} =
             GhEx.Repositories.is_collaborator(
               client(__MODULE__.IsCollaborator),
               "o",
               "r",
               "octocat"
             )
  end

  test "is_collaborator/4 returns false for GitHub's 404 response" do
    Req.Test.stub(__MODULE__.IsNotCollaborator, fn conn ->
      assert conn.request_path == "/repos/o/r/collaborators/octocat"
      Plug.Conn.send_resp(conn, 404, "")
    end)

    assert {:ok, false, %{status: 404}} =
             GhEx.Repositories.is_collaborator(
               client(__MODULE__.IsNotCollaborator),
               "o",
               "r",
               "octocat"
             )
  end

  test "get_collaborator_permission/4 GETs the effective permission and role" do
    Req.Test.stub(__MODULE__.CollaboratorPermission, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/collaborators/octo%2Fcat/permission"

      Req.Test.json(conn, %{
        "permission" => "write",
        "role_name" => "maintain",
        "user" => %{"login" => "octo/cat"}
      })
    end)

    assert {:ok, permission, _meta} =
             GhEx.Repositories.get_collaborator_permission(
               client(__MODULE__.CollaboratorPermission),
               "o",
               "r",
               "octo/cat"
             )

    assert permission == %{
             "permission" => "write",
             "role_name" => "maintain",
             "user" => %{"login" => "octo/cat"}
           }
  end

  test "list_commits/3 GETs commits" do
    Req.Test.stub(__MODULE__.Commits, fn conn ->
      assert conn.request_path == "/repos/o/r/commits"
      Req.Test.json(conn, [%{"sha" => "abc"}])
    end)

    assert {:ok, [%{"sha" => "abc"}], _} =
             GhEx.Repositories.list_commits(client(__MODULE__.Commits), "o", "r")
  end

  test "list_branches/3 GETs branches" do
    Req.Test.stub(__MODULE__.Branches, fn conn ->
      assert conn.request_path == "/repos/o/r/branches"
      Req.Test.json(conn, [%{"name" => "main"}])
    end)

    assert {:ok, [%{"name" => "main"}], _} =
             GhEx.Repositories.list_branches(client(__MODULE__.Branches), "o", "r")
  end

  test "events/3 surfaces the ETag and polling interval" do
    Req.Test.stub(__MODULE__.Events, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/events"

      conn
      |> Plug.Conn.put_resp_header("etag", ~s("events-v1"))
      |> Plug.Conn.put_resp_header("x-poll-interval", "60")
      |> Req.Test.json([%{"id" => "1", "type" => "PushEvent"}])
    end)

    assert {:ok, [%{"id" => "1", "type" => "PushEvent"}], meta} =
             GhEx.Repositories.events(client(__MODULE__.Events), "o", "r")

    assert meta.etag == ~s("events-v1")
    assert meta.headers["x-poll-interval"] == ["60"]
  end

  test "events/4 returns :not_modified for a matching ETag" do
    Req.Test.stub(__MODULE__.EventsNotModified, fn conn ->
      assert conn.request_path == "/repos/o/r/events"
      assert Plug.Conn.get_req_header(conn, "if-none-match") == [~s("events-v1")]

      conn
      |> Plug.Conn.put_resp_header("etag", ~s("events-v1"))
      |> Plug.Conn.put_resp_header("x-poll-interval", "90")
      |> Plug.Conn.send_resp(304, "")
    end)

    assert {:ok, :not_modified, meta} =
             GhEx.Repositories.events(client(__MODULE__.EventsNotModified), "o", "r",
               headers: [{"if-none-match", ~s("events-v1")}]
             )

    assert meta.status == 304
    assert meta.etag == ~s("events-v1")
    assert meta.headers["x-poll-interval"] == ["90"]
  end

  test "stream_for_org/3 auto-paginates org repositories" do
    Req.Test.stub(__MODULE__.StreamOrg, fn conn ->
      assert conn.request_path == "/orgs/acme/repos"
      Req.Test.json(conn, [%{"name" => "a"}])
    end)

    assert client(__MODULE__.StreamOrg)
           |> GhEx.Repositories.stream_for_org("acme")
           |> Enum.to_list() == [%{"name" => "a"}]
  end

  test "stream_for_user/3 auto-paginates user repositories" do
    Req.Test.stub(__MODULE__.StreamUser, fn conn ->
      assert conn.request_path == "/users/josh/repos"
      Req.Test.json(conn, [%{"name" => "b"}])
    end)

    assert client(__MODULE__.StreamUser)
           |> GhEx.Repositories.stream_for_user("josh")
           |> Enum.to_list() == [%{"name" => "b"}]
  end

  test "stream_commits/3 auto-paginates repo commits" do
    Req.Test.stub(__MODULE__.StreamCommits, fn conn ->
      assert conn.request_path == "/repos/o/r/commits"
      Req.Test.json(conn, [%{"sha" => "abc"}])
    end)

    assert client(__MODULE__.StreamCommits)
           |> GhEx.Repositories.stream_commits("o", "r")
           |> Enum.to_list() == [%{"sha" => "abc"}]
  end

  test "stream_branches/3 auto-paginates repo branches" do
    Req.Test.stub(__MODULE__.StreamBranches, fn conn ->
      assert conn.request_path == "/repos/o/r/branches"
      Req.Test.json(conn, [%{"name" => "main"}])
    end)

    assert client(__MODULE__.StreamBranches)
           |> GhEx.Repositories.stream_branches("o", "r")
           |> Enum.to_list() == [%{"name" => "main"}]
  end

  test "stream_events/3 auto-paginates repository events" do
    Req.Test.stub(__MODULE__.StreamEvents, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/events"
      Req.Test.json(conn, [%{"id" => "1", "type" => "PushEvent"}])
    end)

    assert client(__MODULE__.StreamEvents)
           |> GhEx.Repositories.stream_events("o", "r")
           |> Enum.to_list() == [%{"id" => "1", "type" => "PushEvent"}]
  end
end
