defmodule GhEx.CodeSecurityTest do
  use ExUnit.Case, async: true

  defp client(stub), do: GhEx.Testing.client(stub)

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list_alerts/3 GETs code-scanning alerts" do
    Req.Test.stub(__MODULE__.ListCode, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/code-scanning/alerts"
      assert conn.query_string == "state=open"
      Req.Test.json(conn, [%{"number" => 1}])
    end)

    assert {:ok, [%{"number" => 1}], _} =
             GhEx.CodeSecurity.list_alerts(client(__MODULE__.ListCode), "o", "r",
               params: [state: "open"]
             )
  end

  test "stream_alerts/3 auto-paginates code-scanning alerts" do
    Req.Test.stub(__MODULE__.StreamCode, fn conn ->
      assert conn.request_path == "/repos/o/r/code-scanning/alerts"
      Req.Test.json(conn, [%{"number" => 1}])
    end)

    assert client(__MODULE__.StreamCode)
           |> GhEx.CodeSecurity.stream_alerts("o", "r")
           |> Enum.to_list() == [%{"number" => 1}]
  end

  test "get_alert/4 GETs a code-scanning alert" do
    Req.Test.stub(__MODULE__.GetCode, fn conn ->
      assert conn.request_path == "/repos/o/r/code-scanning/alerts/7"
      Req.Test.json(conn, %{"number" => 7, "state" => "open"})
    end)

    assert {:ok, %{"number" => 7}, _} =
             GhEx.CodeSecurity.get_alert(client(__MODULE__.GetCode), "o", "r", 7)
  end

  test "update_alert/5 PATCHes a code-scanning alert" do
    Req.Test.stub(__MODULE__.UpdateCode, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/o/r/code-scanning/alerts/7"
      assert body(conn) == %{"state" => "dismissed", "dismissed_reason" => "false positive"}
      Req.Test.json(conn, %{"number" => 7, "state" => "dismissed"})
    end)

    attrs = %{state: "dismissed", dismissed_reason: "false positive"}

    assert {:ok, %{"number" => 7, "state" => "dismissed"}, _} =
             GhEx.CodeSecurity.update_alert(client(__MODULE__.UpdateCode), "o", "r", 7, attrs)
  end

  test "list_dependabot_alerts/3 GETs Dependabot alerts" do
    Req.Test.stub(__MODULE__.ListDependabot, fn conn ->
      assert conn.request_path == "/repos/o/r/dependabot/alerts"
      assert conn.query_string == "severity=high"
      Req.Test.json(conn, [%{"number" => 2}])
    end)

    assert {:ok, [%{"number" => 2}], _} =
             GhEx.CodeSecurity.list_dependabot_alerts(
               client(__MODULE__.ListDependabot),
               "o",
               "r",
               params: [severity: "high"]
             )
  end

  test "stream_dependabot_alerts/3 auto-paginates Dependabot alerts" do
    Req.Test.stub(__MODULE__.StreamDependabot, fn conn ->
      assert conn.request_path == "/repos/o/r/dependabot/alerts"
      Req.Test.json(conn, [%{"number" => 2}])
    end)

    assert client(__MODULE__.StreamDependabot)
           |> GhEx.CodeSecurity.stream_dependabot_alerts("o", "r")
           |> Enum.to_list() == [%{"number" => 2}]
  end

  test "get_dependabot_alert/4 GETs a Dependabot alert" do
    Req.Test.stub(__MODULE__.GetDependabot, fn conn ->
      assert conn.request_path == "/repos/o/r/dependabot/alerts/8"
      Req.Test.json(conn, %{"number" => 8, "state" => "open"})
    end)

    assert {:ok, %{"number" => 8}, _} =
             GhEx.CodeSecurity.get_dependabot_alert(
               client(__MODULE__.GetDependabot),
               "o",
               "r",
               8
             )
  end

  test "list_secret_alerts/3 GETs secret-scanning alerts" do
    Req.Test.stub(__MODULE__.ListSecret, fn conn ->
      assert conn.request_path == "/repos/o/r/secret-scanning/alerts"
      assert conn.query_string == "hide_secret=true"
      Req.Test.json(conn, [%{"number" => 3}])
    end)

    assert {:ok, [%{"number" => 3}], _} =
             GhEx.CodeSecurity.list_secret_alerts(client(__MODULE__.ListSecret), "o", "r",
               params: [hide_secret: true]
             )
  end

  test "stream_secret_alerts/3 auto-paginates secret-scanning alerts" do
    Req.Test.stub(__MODULE__.StreamSecret, fn conn ->
      assert conn.request_path == "/repos/o/r/secret-scanning/alerts"
      Req.Test.json(conn, [%{"number" => 3}])
    end)

    assert client(__MODULE__.StreamSecret)
           |> GhEx.CodeSecurity.stream_secret_alerts("o", "r")
           |> Enum.to_list() == [%{"number" => 3}]
  end

  test "get_secret_alert/4 GETs a secret-scanning alert" do
    Req.Test.stub(__MODULE__.GetSecret, fn conn ->
      assert conn.request_path == "/repos/o/r/secret-scanning/alerts/9"
      assert conn.query_string == "hide_secret=true"
      Req.Test.json(conn, %{"number" => 9, "secret" => "***"})
    end)

    assert {:ok, %{"number" => 9}, _} =
             GhEx.CodeSecurity.get_secret_alert(client(__MODULE__.GetSecret), "o", "r", 9,
               params: [hide_secret: true]
             )
  end
end
