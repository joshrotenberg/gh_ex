defmodule GhEx.SearchTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp query(conn), do: URI.decode_query(conn.query_string)

  test "repositories/3 searches with q and extra params" do
    Req.Test.stub(__MODULE__.Repos, fn conn ->
      assert conn.request_path == "/search/repositories"
      assert query(conn) == %{"q" => "tetris language:elixir", "sort" => "stars"}
      Req.Test.json(conn, %{"total_count" => 1})
    end)

    assert {:ok, %{"total_count" => 1}, _} =
             GhEx.Search.repositories(client(__MODULE__.Repos), "tetris language:elixir",
               params: [sort: "stars"]
             )
  end

  test "repositories/3 accepts :params as a map" do
    Req.Test.stub(__MODULE__.ReposMap, fn conn ->
      assert conn.request_path == "/search/repositories"
      assert query(conn) == %{"q" => "tetris", "sort" => "stars"}
      Req.Test.json(conn, %{"total_count" => 1})
    end)

    assert {:ok, %{"total_count" => 1}, _} =
             GhEx.Search.repositories(client(__MODULE__.ReposMap), "tetris",
               params: %{sort: "stars"}
             )
  end

  test "code/3 searches code" do
    Req.Test.stub(__MODULE__.Code, fn conn ->
      assert conn.request_path == "/search/code"
      assert query(conn) == %{"q" => "addClass repo:jquery/jquery"}
      Req.Test.json(conn, %{"total_count" => 0})
    end)

    assert {:ok, _, _} =
             GhEx.Search.code(client(__MODULE__.Code), "addClass repo:jquery/jquery")
  end

  test "issues_and_pull_requests/3 searches issues" do
    Req.Test.stub(__MODULE__.Issues, fn conn ->
      assert conn.request_path == "/search/issues"
      assert query(conn) == %{"q" => "is:open label:bug"}
      Req.Test.json(conn, %{"total_count" => 3})
    end)

    assert {:ok, %{"total_count" => 3}, _} =
             GhEx.Search.issues_and_pull_requests(client(__MODULE__.Issues), "is:open label:bug")
  end

  test "users/3 searches users" do
    Req.Test.stub(__MODULE__.Users, fn conn ->
      assert conn.request_path == "/search/users"
      assert query(conn) == %{"q" => "josh"}
      Req.Test.json(conn, %{"total_count" => 5})
    end)

    assert {:ok, %{"total_count" => 5}, _} = GhEx.Search.users(client(__MODULE__.Users), "josh")
  end

  test "commits/3 searches commits" do
    Req.Test.stub(__MODULE__.Commits, fn conn ->
      assert conn.request_path == "/search/commits"
      assert query(conn) == %{"q" => "fix repo:o/r"}
      Req.Test.json(conn, %{"total_count" => 2})
    end)

    assert {:ok, %{"total_count" => 2}, _} =
             GhEx.Search.commits(client(__MODULE__.Commits), "fix repo:o/r")
  end

  test "stream_repositories/3 unwraps items and keeps the q param" do
    Req.Test.stub(__MODULE__.StreamRepos, fn conn ->
      assert conn.request_path == "/search/repositories"
      assert query(conn) == %{"q" => "tetris", "sort" => "stars"}
      Req.Test.json(conn, %{"total_count" => 1, "items" => [%{"id" => 1}]})
    end)

    assert client(__MODULE__.StreamRepos)
           |> GhEx.Search.stream_repositories("tetris", params: [sort: "stars"])
           |> Enum.to_list() == [%{"id" => 1}]
  end

  test "stream_code/3 unwraps items" do
    Req.Test.stub(__MODULE__.StreamCode, fn conn ->
      assert conn.request_path == "/search/code"
      Req.Test.json(conn, %{"items" => [%{"path" => "a.ex"}]})
    end)

    assert client(__MODULE__.StreamCode)
           |> GhEx.Search.stream_code("addClass")
           |> Enum.to_list() == [%{"path" => "a.ex"}]
  end

  test "stream_issues_and_pull_requests/3 unwraps items" do
    Req.Test.stub(__MODULE__.StreamIssues, fn conn ->
      assert conn.request_path == "/search/issues"
      Req.Test.json(conn, %{"items" => [%{"number" => 1}]})
    end)

    assert client(__MODULE__.StreamIssues)
           |> GhEx.Search.stream_issues_and_pull_requests("is:open")
           |> Enum.to_list() == [%{"number" => 1}]
  end

  test "stream_users/3 unwraps items" do
    Req.Test.stub(__MODULE__.StreamUsers, fn conn ->
      assert conn.request_path == "/search/users"
      Req.Test.json(conn, %{"items" => [%{"login" => "josh"}]})
    end)

    assert client(__MODULE__.StreamUsers)
           |> GhEx.Search.stream_users("josh")
           |> Enum.to_list() == [%{"login" => "josh"}]
  end

  test "stream_commits/3 unwraps items" do
    Req.Test.stub(__MODULE__.StreamCommits, fn conn ->
      assert conn.request_path == "/search/commits"
      Req.Test.json(conn, %{"items" => [%{"sha" => "abc"}]})
    end)

    assert client(__MODULE__.StreamCommits)
           |> GhEx.Search.stream_commits("fix")
           |> Enum.to_list() == [%{"sha" => "abc"}]
  end
end
