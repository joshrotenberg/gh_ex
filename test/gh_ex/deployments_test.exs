defmodule GhEx.DeploymentsTest do
  use ExUnit.Case, async: true

  defp client(stub), do: GhEx.Testing.client(stub)

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/3 GETs filtered repository deployments" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/deployments"
      assert conn.query_string == "environment=production"
      Req.Test.json(conn, [%{"id" => 42}])
    end)

    assert {:ok, [%{"id" => 42}], _} =
             GhEx.Deployments.list(client(__MODULE__.List), "o", "r",
               params: [environment: "production"]
             )
  end

  test "stream/3 auto-paginates repository deployments" do
    Req.Test.stub(__MODULE__.Stream, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/deployments"
      Req.Test.json(conn, [%{"id" => 42}])
    end)

    assert client(__MODULE__.Stream)
           |> GhEx.Deployments.stream("o", "r")
           |> Enum.to_list() == [%{"id" => 42}]
  end

  test "get/4 GETs a deployment by id" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/deployments/42"
      Req.Test.json(conn, %{"id" => 42, "ref" => "main"})
    end)

    assert {:ok, %{"id" => 42, "ref" => "main"}, _} =
             GhEx.Deployments.get(client(__MODULE__.Get), "o", "r", 42)
  end

  test "create/4 POSTs a deployment request" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/deployments"

      assert body(conn) == %{
               "ref" => "main",
               "environment" => "production",
               "required_contexts" => []
             }

      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 42})
    end)

    attrs = %{ref: "main", environment: "production", required_contexts: []}

    assert {:ok, %{"id" => 42}, %{status: 201}} =
             GhEx.Deployments.create(client(__MODULE__.Create), "o", "r", attrs)
  end

  test "list_statuses/4 GETs a deployment's status history" do
    Req.Test.stub(__MODULE__.ListStatuses, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/deployments/42/statuses"
      assert conn.query_string == "per_page=10"
      Req.Test.json(conn, [%{"id" => 7, "state" => "success"}])
    end)

    assert {:ok, [%{"state" => "success"}], _} =
             GhEx.Deployments.list_statuses(client(__MODULE__.ListStatuses), "o", "r", 42,
               params: [per_page: 10]
             )
  end

  test "stream_statuses/4 auto-paginates deployment statuses" do
    Req.Test.stub(__MODULE__.StreamStatuses, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/o/r/deployments/42/statuses"
      Req.Test.json(conn, [%{"id" => 7, "state" => "success"}])
    end)

    assert client(__MODULE__.StreamStatuses)
           |> GhEx.Deployments.stream_statuses("o", "r", 42)
           |> Enum.to_list() == [%{"id" => 7, "state" => "success"}]
  end

  test "create_status/5 POSTs a new deployment status" do
    Req.Test.stub(__MODULE__.CreateStatus, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/o/r/deployments/42/statuses"

      assert body(conn) == %{
               "state" => "success",
               "description" => "Deployment finished",
               "log_url" => "https://example.test/deployments/42"
             }

      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 7, "state" => "success"})
    end)

    attrs = %{
      state: "success",
      description: "Deployment finished",
      log_url: "https://example.test/deployments/42"
    }

    assert {:ok, %{"id" => 7, "state" => "success"}, %{status: 201}} =
             GhEx.Deployments.create_status(
               client(__MODULE__.CreateStatus),
               "o",
               "r",
               42,
               attrs
             )
  end
end
