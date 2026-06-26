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
end
