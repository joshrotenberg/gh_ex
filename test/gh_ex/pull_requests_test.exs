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

  test "merge_async/5 PUTs to the asynchronous merge endpoint" do
    Req.Test.stub(__MODULE__.MergeAsync, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/repos/o/r/pulls/7/merge-async"
      assert body(conn) == %{"merge_action" => "default", "merge_method" => "squash"}

      conn
      |> Plug.Conn.put_status(202)
      |> Req.Test.json(%{
        "status" => "pending",
        "details" => %{"uuid" => "merge-uuid"}
      })
    end)

    assert {:ok, %{"status" => "pending", "details" => %{"uuid" => "merge-uuid"}}, meta} =
             GhEx.PullRequests.merge_async(client(__MODULE__.MergeAsync), "o", "r", 7, %{
               merge_action: "default",
               merge_method: "squash"
             })

    assert meta.status == 202
  end

  test "merge_async/4 PUTs with an empty body by default" do
    Req.Test.stub(__MODULE__.MergeAsyncDefault, fn conn ->
      assert conn.request_path == "/repos/o/r/pulls/7/merge-async"
      assert body(conn) == %{}
      conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{"status" => "pending"})
    end)

    assert {:ok, %{"status" => "pending"}, _} =
             GhEx.PullRequests.merge_async(client(__MODULE__.MergeAsyncDefault), "o", "r", 7)
  end

  test "merge_async/5 preserves an existing pending request in a 409 error body" do
    Req.Test.stub(__MODULE__.MergeAsyncConflict, fn conn ->
      conn
      |> Plug.Conn.put_status(409)
      |> Req.Test.json(%{
        "status" => "pending",
        "details" => %{"uuid" => "existing-uuid"}
      })
    end)

    assert {:error,
            %GhEx.Error{
              status: 409,
              body: %{"status" => "pending", "details" => %{"uuid" => "existing-uuid"}}
            }} =
             GhEx.PullRequests.merge_async(
               client(__MODULE__.MergeAsyncConflict),
               "o",
               "r",
               7
             )
  end

  test "get_merge_result/5 GETs the asynchronous merge result" do
    Req.Test.stub(__MODULE__.MergeResult, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/pulls/7/merge-async/merge-uuid"
      Req.Test.json(conn, %{"status" => "merged", "details" => %{"sha" => "abc123"}})
    end)

    assert {:ok, %{"status" => "merged", "details" => %{"sha" => "abc123"}}, _} =
             GhEx.PullRequests.get_merge_result(
               client(__MODULE__.MergeResult),
               "o",
               "r",
               7,
               "merge-uuid"
             )
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

  test "stream/3 auto-paginates repo pull requests" do
    Req.Test.stub(__MODULE__.Stream, fn conn ->
      assert conn.request_path == "/repos/o/r/pulls"
      Req.Test.json(conn, [%{"number" => 1}])
    end)

    assert client(__MODULE__.Stream) |> GhEx.PullRequests.stream("o", "r") |> Enum.to_list() ==
             [%{"number" => 1}]
  end

  test "stream_files/4 auto-paginates pull request files" do
    Req.Test.stub(__MODULE__.StreamFiles, fn conn ->
      assert conn.request_path == "/repos/o/r/pulls/42/files"
      Req.Test.json(conn, [%{"filename" => "a.ex"}])
    end)

    assert client(__MODULE__.StreamFiles)
           |> GhEx.PullRequests.stream_files("o", "r", 42)
           |> Enum.to_list() == [%{"filename" => "a.ex"}]
  end

  test "stream_reviews/4 auto-paginates pull request reviews" do
    Req.Test.stub(__MODULE__.StreamReviews, fn conn ->
      assert conn.request_path == "/repos/o/r/pulls/42/reviews"
      Req.Test.json(conn, [%{"id" => 1}])
    end)

    assert client(__MODULE__.StreamReviews)
           |> GhEx.PullRequests.stream_reviews("o", "r", 42)
           |> Enum.to_list() == [%{"id" => 1}]
  end
end
