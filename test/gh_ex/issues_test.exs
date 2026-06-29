defmodule GhEx.IssuesTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/3 GETs repo issues and passes params" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/issues"
      assert conn.query_string == "state=open"
      Req.Test.json(conn, [%{"number" => 1}])
    end)

    assert {:ok, [%{"number" => 1}], _meta} =
             GhEx.Issues.list(client(__MODULE__.List), "o", "r", params: [state: "open"])
  end

  test "get/4 GETs a single issue" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/repos/o/r/issues/7"
      Req.Test.json(conn, %{"number" => 7})
    end)

    assert {:ok, %{"number" => 7}, _} = GhEx.Issues.get(client(__MODULE__.Get), "o", "r", 7)
  end

  test "create/4 POSTs the issue body" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/issues"
      assert body(conn) == %{"title" => "Bug"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"number" => 7})
    end)

    assert {:ok, %{"number" => 7}, _} =
             GhEx.Issues.create(client(__MODULE__.Create), "o", "r", %{title: "Bug"})
  end

  test "create/4 sends attrs as the body, ignoring a :json in opts" do
    Req.Test.stub(__MODULE__.JsonIgnored, fn conn ->
      assert body(conn) == %{"title" => "Bug"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"number" => 7})
    end)

    assert {:ok, %{"number" => 7}, _} =
             GhEx.Issues.create(
               client(__MODULE__.JsonIgnored),
               "o",
               "r",
               %{title: "Bug"},
               json: %{title: "caller override"}
             )
  end

  test "update/5 PATCHes the issue" do
    Req.Test.stub(__MODULE__.Update, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/o/r/issues/7"
      assert body(conn) == %{"state" => "closed"}
      Req.Test.json(conn, %{"number" => 7, "state" => "closed"})
    end)

    assert {:ok, %{"state" => "closed"}, _} =
             GhEx.Issues.update(client(__MODULE__.Update), "o", "r", 7, %{state: "closed"})
  end

  test "list_comments/4 GETs issue comments" do
    Req.Test.stub(__MODULE__.Comments, fn conn ->
      assert conn.request_path == "/repos/o/r/issues/7/comments"
      Req.Test.json(conn, [%{"id" => 1}])
    end)

    assert {:ok, [%{"id" => 1}], _} =
             GhEx.Issues.list_comments(client(__MODULE__.Comments), "o", "r", 7)
  end

  test "create_comment/5 POSTs a comment body" do
    Req.Test.stub(__MODULE__.Comment, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/issues/7/comments"
      assert body(conn) == %{"body" => "thanks"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 1})
    end)

    assert {:ok, %{"id" => 1}, _} =
             GhEx.Issues.create_comment(client(__MODULE__.Comment), "o", "r", 7, "thanks")
  end

  test "add_labels/5 POSTs the label list" do
    Req.Test.stub(__MODULE__.Labels, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/issues/7/labels"
      assert body(conn) == %{"labels" => ["bug", "p1"]}
      Req.Test.json(conn, [%{"name" => "bug"}, %{"name" => "p1"}])
    end)

    assert {:ok, _labels, _} =
             GhEx.Issues.add_labels(client(__MODULE__.Labels), "o", "r", 7, ["bug", "p1"])
  end

  test "stream/3 auto-paginates repo issues" do
    Req.Test.stub(__MODULE__.Stream, fn conn ->
      assert conn.request_path == "/repos/o/r/issues"
      Req.Test.json(conn, [%{"number" => 1}, %{"number" => 2}])
    end)

    assert client(__MODULE__.Stream) |> GhEx.Issues.stream("o", "r") |> Enum.to_list() ==
             [%{"number" => 1}, %{"number" => 2}]
  end

  test "stream_comments/4 auto-paginates issue comments" do
    Req.Test.stub(__MODULE__.StreamComments, fn conn ->
      assert conn.request_path == "/repos/o/r/issues/7/comments"
      Req.Test.json(conn, [%{"id" => 1}])
    end)

    assert client(__MODULE__.StreamComments)
           |> GhEx.Issues.stream_comments("o", "r", 7)
           |> Enum.to_list() == [%{"id" => 1}]
  end
end
