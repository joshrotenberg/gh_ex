defmodule GhEx.ActivityTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  test "list_repo_events/3 GETs repository events" do
    Req.Test.stub(__MODULE__.RepoEvents, fn conn ->
      assert conn.request_path == "/repos/o/r/events"
      assert conn.query_string == "per_page=50"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert {:ok, [%{"id" => "1"}], _} =
             GhEx.Activity.list_repo_events(client(__MODULE__.RepoEvents), "o", "r",
               params: [per_page: 50]
             )
  end

  test "stream_repo_events/3 auto-paginates repository events" do
    Req.Test.stub(__MODULE__.StreamRepoEvents, fn conn ->
      assert conn.request_path == "/repos/o/r/events"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert client(__MODULE__.StreamRepoEvents)
           |> GhEx.Activity.stream_repo_events("o", "r")
           |> Enum.to_list() == [%{"id" => "1"}]
  end

  test "list_org_events/2 GETs organization events" do
    Req.Test.stub(__MODULE__.OrgEvents, fn conn ->
      assert conn.request_path == "/orgs/acme/events"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert {:ok, [%{"id" => "1"}], _} =
             GhEx.Activity.list_org_events(client(__MODULE__.OrgEvents), "acme")
  end

  test "stream_org_events/2 auto-paginates organization events" do
    Req.Test.stub(__MODULE__.StreamOrgEvents, fn conn ->
      assert conn.request_path == "/orgs/acme/events"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert client(__MODULE__.StreamOrgEvents)
           |> GhEx.Activity.stream_org_events("acme")
           |> Enum.to_list() == [%{"id" => "1"}]
  end

  test "list_user_events/2 GETs events performed by a user" do
    Req.Test.stub(__MODULE__.UserEvents, fn conn ->
      assert conn.request_path == "/users/octocat/events"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert {:ok, [%{"id" => "1"}], _} =
             GhEx.Activity.list_user_events(client(__MODULE__.UserEvents), "octocat")
  end

  test "stream_user_events/2 auto-paginates user events" do
    Req.Test.stub(__MODULE__.StreamUserEvents, fn conn ->
      assert conn.request_path == "/users/octocat/events"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert client(__MODULE__.StreamUserEvents)
           |> GhEx.Activity.stream_user_events("octocat")
           |> Enum.to_list() == [%{"id" => "1"}]
  end

  test "list_public_events/1 GETs public events" do
    Req.Test.stub(__MODULE__.PublicEvents, fn conn ->
      assert conn.request_path == "/events"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert {:ok, [%{"id" => "1"}], _} =
             GhEx.Activity.list_public_events(client(__MODULE__.PublicEvents))
  end

  test "stream_public_events/1 auto-paginates public events" do
    Req.Test.stub(__MODULE__.StreamPublicEvents, fn conn ->
      assert conn.request_path == "/events"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert client(__MODULE__.StreamPublicEvents)
           |> GhEx.Activity.stream_public_events()
           |> Enum.to_list() == [%{"id" => "1"}]
  end

  test "list_stargazers/3 GETs stargazers and passes media-type headers" do
    Req.Test.stub(__MODULE__.Stargazers, fn conn ->
      assert conn.request_path == "/repos/o/r/stargazers"
      assert Plug.Conn.get_req_header(conn, "accept") == ["application/vnd.github.star+json"]
      Req.Test.json(conn, [%{"starred_at" => "2026-07-31T00:00:00Z"}])
    end)

    assert {:ok, [%{"starred_at" => _}], _} =
             GhEx.Activity.list_stargazers(client(__MODULE__.Stargazers), "o", "r",
               headers: [{"accept", "application/vnd.github.star+json"}]
             )
  end

  test "stream_stargazers/3 auto-paginates stargazers" do
    Req.Test.stub(__MODULE__.StreamStargazers, fn conn ->
      assert conn.request_path == "/repos/o/r/stargazers"
      Req.Test.json(conn, [%{"login" => "octocat"}])
    end)

    assert client(__MODULE__.StreamStargazers)
           |> GhEx.Activity.stream_stargazers("o", "r")
           |> Enum.to_list() == [%{"login" => "octocat"}]
  end

  test "list_starred/2 GETs repositories starred by a user" do
    Req.Test.stub(__MODULE__.Starred, fn conn ->
      assert conn.request_path == "/users/octocat/starred"
      Req.Test.json(conn, [%{"full_name" => "o/r"}])
    end)

    assert {:ok, [%{"full_name" => "o/r"}], _} =
             GhEx.Activity.list_starred(client(__MODULE__.Starred), "octocat")
  end

  test "stream_starred/2 auto-paginates repositories starred by a user" do
    Req.Test.stub(__MODULE__.StreamStarred, fn conn ->
      assert conn.request_path == "/users/octocat/starred"
      Req.Test.json(conn, [%{"full_name" => "o/r"}])
    end)

    assert client(__MODULE__.StreamStarred)
           |> GhEx.Activity.stream_starred("octocat")
           |> Enum.to_list() == [%{"full_name" => "o/r"}]
  end

  test "starred?/3 normalizes 204 to true with response metadata" do
    Req.Test.stub(__MODULE__.IsStarred, fn conn ->
      assert conn.request_path == "/user/starred/o/r"

      conn
      |> Plug.Conn.put_resp_header("etag", ~s("starred"))
      |> Plug.Conn.put_resp_header("x-ratelimit-limit", "5000")
      |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "4999")
      |> Plug.Conn.send_resp(204, "")
    end)

    assert {:ok, true, meta} = GhEx.Activity.starred?(client(__MODULE__.IsStarred), "o", "r")
    assert meta.status == 204
    assert meta.etag == ~s("starred")
    assert meta.rate_limit.limit == 5000
  end

  test "starred?/3 normalizes only 404 to false" do
    Req.Test.stub(__MODULE__.NotStarred, fn conn ->
      conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{"message" => "Not Found"})
    end)

    assert {:ok, false, %GhEx.REST.Meta{status: 404}} =
             GhEx.Activity.starred?(client(__MODULE__.NotStarred), "o", "r")

    Req.Test.stub(__MODULE__.Forbidden, fn conn ->
      conn |> Plug.Conn.put_status(403) |> Req.Test.json(%{"message" => "Forbidden"})
    end)

    assert {:error, %GhEx.Error{status: 403}} =
             GhEx.Activity.starred?(client(__MODULE__.Forbidden), "o", "r")
  end

  test "star/3 PUTs the authenticated user's star" do
    Req.Test.stub(__MODULE__.Star, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/user/starred/o/r"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, %GhEx.REST.Meta{status: 204}} =
             GhEx.Activity.star(client(__MODULE__.Star), "o", "r")
  end

  test "unstar/3 DELETEs the authenticated user's star" do
    Req.Test.stub(__MODULE__.Unstar, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/user/starred/o/r"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, %GhEx.REST.Meta{status: 204}} =
             GhEx.Activity.unstar(client(__MODULE__.Unstar), "o", "r")
  end
end
