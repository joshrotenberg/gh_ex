defmodule GhEx.HooksTest do
  use ExUnit.Case, async: true

  defp client(stub), do: GhEx.Testing.client(stub)

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/3 GETs repository hooks" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/hooks"
      assert conn.query_string == "per_page=50"
      Req.Test.json(conn, [%{"id" => 42}])
    end)

    assert {:ok, [%{"id" => 42}], _} =
             GhEx.Hooks.list(client(__MODULE__.List), "o", "r", params: [per_page: 50])
  end

  test "stream/3 auto-paginates repository hooks" do
    Req.Test.stub(__MODULE__.Stream, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/hooks"
      Req.Test.json(conn, [%{"id" => 42}])
    end)

    assert client(__MODULE__.Stream)
           |> GhEx.Hooks.stream("o", "r")
           |> Enum.to_list() == [%{"id" => 42}]
  end

  test "get/4 GETs a repository hook" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/hooks/42"
      Req.Test.json(conn, %{"id" => 42, "active" => true})
    end)

    assert {:ok, %{"id" => 42, "active" => true}, _} =
             GhEx.Hooks.get(client(__MODULE__.Get), "o", "r", 42)
  end

  test "create/4 POSTs a repository hook" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/hooks"

      assert body(conn) == %{
               "active" => true,
               "events" => ["push"],
               "config" => %{
                 "url" => "https://example.test/github",
                 "content_type" => "json",
                 "secret" => "secret"
               }
             }

      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 42})
    end)

    attrs = %{
      active: true,
      events: ["push"],
      config: %{url: "https://example.test/github", content_type: "json", secret: "secret"}
    }

    assert {:ok, %{"id" => 42}, %{status: 201}} =
             GhEx.Hooks.create(client(__MODULE__.Create), "o", "r", attrs)
  end

  test "update/5 PATCHes a repository hook" do
    Req.Test.stub(__MODULE__.Update, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/o/r/hooks/42"
      assert body(conn) == %{"active" => false, "events" => ["push", "pull_request"]}
      Req.Test.json(conn, %{"id" => 42, "active" => false})
    end)

    attrs = %{active: false, events: ["push", "pull_request"]}

    assert {:ok, %{"id" => 42, "active" => false}, _} =
             GhEx.Hooks.update(client(__MODULE__.Update), "o", "r", 42, attrs)
  end

  test "delete/4 DELETEs a repository hook" do
    Req.Test.stub(__MODULE__.Delete, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/o/r/hooks/42"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, %{status: 204}} =
             GhEx.Hooks.delete(client(__MODULE__.Delete), "o", "r", 42)
  end

  test "ping/4 POSTs a bodyless ping" do
    Req.Test.stub(__MODULE__.Ping, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/hooks/42/pings"
      assert {:ok, "", _conn} = Plug.Conn.read_body(conn)
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, %{status: 204}} = GhEx.Hooks.ping(client(__MODULE__.Ping), "o", "r", 42)
  end

  test "test/4 POSTs a bodyless push test" do
    Req.Test.stub(__MODULE__.Test, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/hooks/42/tests"
      assert {:ok, "", _conn} = Plug.Conn.read_body(conn)
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, %{status: 204}} = GhEx.Hooks.test(client(__MODULE__.Test), "o", "r", 42)
  end
end
