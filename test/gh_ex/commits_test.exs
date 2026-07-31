defmodule GhEx.CommitsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "get/4 GETs a commit and encodes a branch ref as one segment" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/feature%2Fone"
      Req.Test.json(conn, %{"sha" => "abc123"})
    end)

    assert {:ok, %{"sha" => "abc123"}, _} =
             GhEx.Commits.get(client(__MODULE__.Get), "o", "r", "feature/one")
  end

  test "compare/5 GETs the encoded base...head pair and passes pagination" do
    Req.Test.stub(__MODULE__.Compare, fn conn ->
      assert conn.request_path == "/repos/o/r/compare/main...octocat%3Afeature%2Fone"
      assert conn.query_string == "per_page=100"
      Req.Test.json(conn, %{"status" => "ahead", "ahead_by" => 2})
    end)

    assert {:ok, %{"ahead_by" => 2}, _} =
             GhEx.Commits.compare(
               client(__MODULE__.Compare),
               "o",
               "r",
               "main",
               "octocat:feature/one",
               params: [per_page: 100]
             )
  end

  test "list_pulls/4 GETs pull requests associated with a commit" do
    Req.Test.stub(__MODULE__.Pulls, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/abc123/pulls"
      Req.Test.json(conn, [%{"number" => 7}])
    end)

    assert {:ok, [%{"number" => 7}], _} =
             GhEx.Commits.list_pulls(client(__MODULE__.Pulls), "o", "r", "abc123")
  end

  test "stream_pulls/4 auto-paginates associated pull requests" do
    Req.Test.stub(__MODULE__.StreamPulls, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/abc123/pulls"
      Req.Test.json(conn, [%{"number" => 7}])
    end)

    assert client(__MODULE__.StreamPulls)
           |> GhEx.Commits.stream_pulls("o", "r", "abc123")
           |> Enum.to_list() == [%{"number" => 7}]
  end

  test "list_comments/4 GETs commit comments" do
    Req.Test.stub(__MODULE__.Comments, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/abc123/comments"
      Req.Test.json(conn, [%{"id" => 11, "body" => "Looks good"}])
    end)

    assert {:ok, [%{"id" => 11}], _} =
             GhEx.Commits.list_comments(client(__MODULE__.Comments), "o", "r", "abc123")
  end

  test "stream_comments/4 auto-paginates commit comments" do
    Req.Test.stub(__MODULE__.StreamComments, fn conn ->
      assert conn.request_path == "/repos/o/r/commits/abc123/comments"
      Req.Test.json(conn, [%{"id" => 11}])
    end)

    assert client(__MODULE__.StreamComments)
           |> GhEx.Commits.stream_comments("o", "r", "abc123")
           |> Enum.to_list() == [%{"id" => 11}]
  end

  test "create_comment/5 POSTs a diff-anchored comment and owns the JSON body" do
    Req.Test.stub(__MODULE__.CreateComment, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/commits/abc123/comments"

      assert body(conn) == %{
               "body" => "Please revisit this.",
               "path" => "lib/a.ex",
               "position" => 4
             }

      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 11})
    end)

    assert {:ok, %{"id" => 11}, _} =
             GhEx.Commits.create_comment(
               client(__MODULE__.CreateComment),
               "o",
               "r",
               "abc123",
               %{body: "Please revisit this.", path: "lib/a.ex", position: 4},
               json: %{body: "caller override"}
             )
  end
end
