defmodule GhEx.NotificationsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/2 GETs the inbox and passes params" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/notifications"
      assert conn.query_string == "participating=true"
      Req.Test.json(conn, [%{"id" => "1", "reason" => "mention"}])
    end)

    assert {:ok, [%{"reason" => "mention"}], _meta} =
             GhEx.Notifications.list(client(__MODULE__.List), params: [participating: true])
  end

  test "list/2 supports a conditional request that returns 304 Not Modified" do
    Req.Test.stub(__MODULE__.Cond, fn conn ->
      assert [~s("etag123")] = Plug.Conn.get_req_header(conn, "if-none-match")

      conn
      |> Plug.Conn.put_resp_header("x-poll-interval", "60")
      |> Plug.Conn.send_resp(304, "")
    end)

    assert {:ok, :not_modified, meta} =
             GhEx.Notifications.list(client(__MODULE__.Cond),
               headers: [{"if-none-match", ~s("etag123")}]
             )

    assert meta.status == 304
    assert GhEx.Notifications.poll_interval(meta) == 60
  end

  test "list_repo/4 GETs a repository's notifications" do
    Req.Test.stub(__MODULE__.ListRepo, fn conn ->
      assert conn.request_path == "/repos/o/r/notifications"
      Req.Test.json(conn, [%{"id" => "1"}])
    end)

    assert {:ok, [%{"id" => "1"}], _} =
             GhEx.Notifications.list_repo(client(__MODULE__.ListRepo), "o", "r")
  end

  test "get_thread/3 GETs a single thread" do
    Req.Test.stub(__MODULE__.Thread, fn conn ->
      assert conn.request_path == "/notifications/threads/42"
      Req.Test.json(conn, %{"id" => "42"})
    end)

    assert {:ok, %{"id" => "42"}, _} =
             GhEx.Notifications.get_thread(client(__MODULE__.Thread), 42)
  end

  test "mark_thread_read/3 PATCHes the thread" do
    Req.Test.stub(__MODULE__.ThreadRead, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/notifications/threads/42"
      Plug.Conn.send_resp(conn, 205, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Notifications.mark_thread_read(client(__MODULE__.ThreadRead), 42)

    assert meta.status == 205
  end

  test "mark_thread_done/3 DELETEs the thread" do
    Req.Test.stub(__MODULE__.ThreadDone, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/notifications/threads/42"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Notifications.mark_thread_done(client(__MODULE__.ThreadDone), 42)

    assert meta.status == 204
  end

  test "mark_read/2 PUTs an empty body by default" do
    Req.Test.stub(__MODULE__.MarkRead, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/notifications"
      assert body(conn) == %{}
      Plug.Conn.send_resp(conn, 202, "")
    end)

    assert {:ok, _body, meta} = GhEx.Notifications.mark_read(client(__MODULE__.MarkRead))
    assert meta.status == 202
  end

  test "mark_read/2 sends last_read_at when given" do
    Req.Test.stub(__MODULE__.MarkReadAt, fn conn ->
      assert body(conn) == %{"last_read_at" => "2026-07-01T00:00:00Z"}
      Plug.Conn.send_resp(conn, 202, "")
    end)

    assert {:ok, _, _} =
             GhEx.Notifications.mark_read(client(__MODULE__.MarkReadAt),
               last_read_at: "2026-07-01T00:00:00Z"
             )
  end

  test "mark_repo_read/4 PUTs to the repo notifications endpoint" do
    Req.Test.stub(__MODULE__.RepoRead, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/repos/o/r/notifications"
      assert body(conn) == %{}
      Plug.Conn.send_resp(conn, 202, "")
    end)

    assert {:ok, _, meta} =
             GhEx.Notifications.mark_repo_read(client(__MODULE__.RepoRead), "o", "r")

    assert meta.status == 202
  end

  test "get_thread_subscription/3 GETs the thread subscription" do
    Req.Test.stub(__MODULE__.GetSub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/notifications/threads/42/subscription"
      Req.Test.json(conn, %{"subscribed" => true, "ignored" => false})
    end)

    assert {:ok, %{"subscribed" => true}, _} =
             GhEx.Notifications.get_thread_subscription(client(__MODULE__.GetSub), 42)
  end

  test "set_thread_subscription/4 PUTs the subscription body" do
    Req.Test.stub(__MODULE__.SetSub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/notifications/threads/42/subscription"
      assert body(conn) == %{"ignored" => true}
      Req.Test.json(conn, %{"ignored" => true})
    end)

    assert {:ok, %{"ignored" => true}, _} =
             GhEx.Notifications.set_thread_subscription(client(__MODULE__.SetSub), 42, %{
               ignored: true
             })
  end

  test "delete_thread_subscription/3 DELETEs the subscription" do
    Req.Test.stub(__MODULE__.DelSub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/notifications/threads/42/subscription"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _body, meta} =
             GhEx.Notifications.delete_thread_subscription(client(__MODULE__.DelSub), 42)

    assert meta.status == 204
  end

  describe "poll_interval/2" do
    test "reads the X-Poll-Interval header" do
      meta = %GhEx.REST.Meta{headers: %{"x-poll-interval" => ["90"]}}
      assert GhEx.Notifications.poll_interval(meta) == 90
    end

    test "returns the default when the header is absent" do
      assert GhEx.Notifications.poll_interval(%GhEx.REST.Meta{headers: %{}}) == 60
      assert GhEx.Notifications.poll_interval(%GhEx.REST.Meta{headers: %{}}, 30) == 30
    end

    test "returns the default when the header is not a valid integer" do
      meta = %GhEx.REST.Meta{headers: %{"x-poll-interval" => ["soon"]}}
      assert GhEx.Notifications.poll_interval(meta, 15) == 15
    end

    test "returns the default when headers are not a map" do
      assert GhEx.Notifications.poll_interval(%GhEx.REST.Meta{headers: []}, 20) == 20
    end
  end
end
