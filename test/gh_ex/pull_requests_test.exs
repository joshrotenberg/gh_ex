defmodule GhEx.PullRequestsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/3 GETs repo pulls and passes params" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/pulls"
      assert conn.query_string == "state=open"
      Req.Test.json(conn, [%{"number" => 1}])
    end)

    assert {:ok, [%{"number" => 1}], _} =
             GhEx.PullRequests.list(client(__MODULE__.List), "o", "r", params: [state: "open"])
  end

  test "get/4 GETs a single pull request" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/repos/o/r/pulls/7"
      Req.Test.json(conn, %{"number" => 7})
    end)

    assert {:ok, %{"number" => 7}, _} = GhEx.PullRequests.get(client(__MODULE__.Get), "o", "r", 7)
  end

  test "create/4 POSTs the pull request body" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/pulls"
      assert body(conn) == %{"title" => "Feature", "head" => "f", "base" => "main"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"number" => 7})
    end)

    assert {:ok, %{"number" => 7}, _} =
             GhEx.PullRequests.create(client(__MODULE__.Create), "o", "r", %{
               title: "Feature",
               head: "f",
               base: "main"
             })
  end

  test "update/5 PATCHes the pull request" do
    Req.Test.stub(__MODULE__.Update, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/o/r/pulls/7"
      assert body(conn) == %{"state" => "closed"}
      Req.Test.json(conn, %{"number" => 7})
    end)

    assert {:ok, _, _} =
             GhEx.PullRequests.update(client(__MODULE__.Update), "o", "r", 7, %{state: "closed"})
  end

  test "merge/5 PUTs to the merge endpoint with options" do
    Req.Test.stub(__MODULE__.Merge, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/repos/o/r/pulls/7/merge"
      assert body(conn) == %{"merge_method" => "squash"}
      Req.Test.json(conn, %{"merged" => true})
    end)

    assert {:ok, %{"merged" => true}, _} =
             GhEx.PullRequests.merge(client(__MODULE__.Merge), "o", "r", 7, %{
               merge_method: "squash"
             })
  end

  test "merge/4 PUTs with an empty body by default" do
    Req.Test.stub(__MODULE__.MergeDefault, fn conn ->
      assert conn.method == "PUT"
      assert body(conn) == %{}
      Req.Test.json(conn, %{"merged" => true})
    end)

    assert {:ok, %{"merged" => true}, _} =
             GhEx.PullRequests.merge(client(__MODULE__.MergeDefault), "o", "r", 7)
  end

  test "list_files/4 GETs the changed files" do
    Req.Test.stub(__MODULE__.Files, fn conn ->
      assert conn.request_path == "/repos/o/r/pulls/7/files"
      Req.Test.json(conn, [%{"filename" => "a.ex"}])
    end)

    assert {:ok, [%{"filename" => "a.ex"}], _} =
             GhEx.PullRequests.list_files(client(__MODULE__.Files), "o", "r", 7)
  end

  test "list_reviews/4 GETs the reviews" do
    Req.Test.stub(__MODULE__.Reviews, fn conn ->
      assert conn.request_path == "/repos/o/r/pulls/7/reviews"
      Req.Test.json(conn, [%{"id" => 1, "state" => "APPROVED"}])
    end)

    assert {:ok, [%{"state" => "APPROVED"}], _} =
             GhEx.PullRequests.list_reviews(client(__MODULE__.Reviews), "o", "r", 7)
  end

  test "create_review/5 POSTs a review" do
    Req.Test.stub(__MODULE__.Review, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/pulls/7/reviews"
      assert body(conn) == %{"event" => "APPROVE"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 1})
    end)

    assert {:ok, %{"id" => 1}, _} =
             GhEx.PullRequests.create_review(client(__MODULE__.Review), "o", "r", 7, %{
               event: "APPROVE"
             })
  end
end
