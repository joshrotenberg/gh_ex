defmodule GhEx.GraphQLTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "secret"}, req_options: [plug: {Req.Test, stub}])
  end

  defp decode_body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  describe "query/3" do
    test "POSTs the query, injects auth + version headers, returns {:ok, data, meta}" do
      Req.Test.stub(__MODULE__.OK, fn conn ->
        assert conn.method == "POST"
        assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
        assert ["2022-11-28"] = Plug.Conn.get_req_header(conn, "x-github-api-version")
        assert %{"query" => q} = decode_body(conn)
        assert q =~ "viewer"
        Req.Test.json(conn, %{"data" => %{"viewer" => %{"login" => "josh"}}})
      end)

      assert {:ok, data, meta} =
               GhEx.GraphQL.query(client(__MODULE__.OK), "query { viewer { login } }")

      assert data == %{"viewer" => %{"login" => "josh"}}
      assert meta.status == 200
    end

    test "normalizes a non-200 HTTP response into a GhEx.Error" do
      Req.Test.stub(__MODULE__.HTTP503, fn conn ->
        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"message" => "Service Unavailable"})
      end)

      assert {:error, %GhEx.Error{status: 503, message: "Service Unavailable"}} =
               GhEx.GraphQL.query(client(__MODULE__.HTTP503), "query { viewer { login } }")
    end

    test "passes variables through in the envelope" do
      Req.Test.stub(__MODULE__.Vars, fn conn ->
        assert %{"variables" => %{"login" => "josh"}} = decode_body(conn)
        Req.Test.json(conn, %{"data" => %{"user" => %{"name" => "Josh"}}})
      end)

      assert {:ok, %{"user" => %{"name" => "Josh"}}, _meta} =
               GhEx.GraphQL.query(
                 client(__MODULE__.Vars),
                 "query($login: String!) { user(login: $login) { name } }",
                 login: "josh"
               )
    end

    test "normalizes a 200-with-errors body into a GhEx.Error, preserving partial data" do
      Req.Test.stub(__MODULE__.Err, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"viewer" => nil},
          "errors" => [%{"message" => "Bad credentials", "type" => "FORBIDDEN"}]
        })
      end)

      assert {:error, %GhEx.Error{} = err} =
               GhEx.GraphQL.query(client(__MODULE__.Err), "query { viewer { login } }")

      assert err.message == "Bad credentials"
      assert [%{"type" => "FORBIDDEN"}] = err.errors
      assert err.body["data"] == %{"viewer" => nil}
      assert Exception.message(err) =~ "Bad credentials"
    end

    test "empty errors array is treated as success" do
      Req.Test.stub(__MODULE__.EmptyErr, fn conn ->
        Req.Test.json(conn, %{"data" => %{"viewer" => %{"login" => "josh"}}, "errors" => []})
      end)

      assert {:ok, %{"viewer" => %{"login" => "josh"}}, _meta} =
               GhEx.GraphQL.query(client(__MODULE__.EmptyErr), "query { viewer { login } }")
    end

    test "labels a 200 with a non-map body as a shape error, not an HTTP 200 error" do
      Req.Test.stub(__MODULE__.NonMap, fn conn ->
        Req.Test.json(conn, ["unexpected", "array"])
      end)

      assert {:error, %GhEx.Error{} = err} =
               GhEx.GraphQL.query(client(__MODULE__.NonMap), "query { viewer { login } }")

      assert err.status == nil
      assert err.body == ["unexpected", "array"]
      assert err.errors == nil
      refute Exception.message(err) =~ "HTTP 200"
      assert Exception.message(err) =~ "not a JSON object"
    end

    test "exposes the rateLimit cost block on meta when selected" do
      Req.Test.stub(__MODULE__.Cost, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"rateLimit" => %{"cost" => 1, "remaining" => 4999}}
        })
      end)

      assert {:ok, _data, meta} =
               GhEx.GraphQL.query(
                 client(__MODULE__.Cost),
                 "query { rateLimit { cost remaining } }"
               )

      assert meta.cost == %{"cost" => 1, "remaining" => 4999}
    end
  end

  describe "stream/4" do
    test "walks pageInfo across pages and flattens nodes" do
      Req.Test.stub(__MODULE__.Pages, fn conn ->
        case decode_body(conn) do
          %{"variables" => %{"cursor" => nil}} ->
            Req.Test.json(conn, %{
              "data" => %{
                "organization" => %{
                  "projectsV2" => %{
                    "nodes" => [%{"title" => "A"}, %{"title" => "B"}],
                    "pageInfo" => %{"hasNextPage" => true, "endCursor" => "CUR2"}
                  }
                }
              }
            })

          %{"variables" => %{"cursor" => "CUR2"}} ->
            Req.Test.json(conn, %{
              "data" => %{
                "organization" => %{
                  "projectsV2" => %{
                    "nodes" => [%{"title" => "C"}],
                    "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil}
                  }
                }
              }
            })
        end
      end)

      titles =
        client(__MODULE__.Pages)
        |> GhEx.GraphQL.stream(
          "query($org: String!, $cursor: String) { ... }",
          [org: "joshrotenberg"],
          path: ["organization", "projectsV2"]
        )
        |> Stream.map(& &1["title"])
        |> Enum.to_list()

      assert titles == ["A", "B", "C"]
    end

    test "halts on a page with hasNextPage true but a nil endCursor instead of looping" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Req.Test.stub(__MODULE__.NilCursor, fn conn ->
        Agent.update(counter, &(&1 + 1))

        Req.Test.json(conn, %{
          "data" => %{
            "organization" => %{
              "projectsV2" => %{
                "nodes" => [%{"title" => "A"}],
                "pageInfo" => %{"hasNextPage" => true, "endCursor" => nil}
              }
            }
          }
        })
      end)

      titles =
        client(__MODULE__.NilCursor)
        |> GhEx.GraphQL.stream(
          "query($org: String!, $cursor: String) { ... }",
          [org: "joshrotenberg"],
          path: ["organization", "projectsV2"]
        )
        |> Stream.map(& &1["title"])
        |> Enum.to_list()

      assert titles == ["A"]
      assert Agent.get(counter, & &1) == 1
    end

    test "halts cleanly when :path traverses a list instead of raising ArgumentError" do
      Req.Test.stub(__MODULE__.ListPath, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"organization" => %{"nodes" => [%{"title" => "A"}]}}
        })
      end)

      titles =
        client(__MODULE__.ListPath)
        |> GhEx.GraphQL.stream(
          "query($org: String!, $cursor: String) { ... }",
          [org: "joshrotenberg"],
          path: ["organization", "nodes", "projectsV2"]
        )
        |> Stream.map(& &1["title"])
        |> Enum.to_list()

      assert titles == []
    end

    test "raises GhEx.Error when a page returns GraphQL errors" do
      Req.Test.stub(__MODULE__.StreamErr, fn conn ->
        Req.Test.json(conn, %{"data" => nil, "errors" => [%{"message" => "boom"}]})
      end)

      assert_raise GhEx.Error, ~r/boom/, fn ->
        client(__MODULE__.StreamErr)
        |> GhEx.GraphQL.stream("query { ... }", path: ["x"])
        |> Enum.to_list()
      end
    end
  end

  describe "telemetry" do
    setup %{test: test} do
      :telemetry.attach_many(
        "#{test}",
        [[:gh_ex, :graphql, :start], [:gh_ex, :graphql, :stop]],
        fn event, measurements, metadata, pid ->
          send(pid, {:telemetry, event, measurements, metadata})
        end,
        self()
      )

      on_exit(fn -> :telemetry.detach("#{test}") end)
    end

    test "emits start and stop with status, rate_limit, and cost on success" do
      Req.Test.stub(__MODULE__.TelOK, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "4999")
        |> Req.Test.json(%{
          "data" => %{"viewer" => %{"login" => "josh"}, "rateLimit" => %{"cost" => 1}}
        })
      end)

      assert {:ok, _data, _meta} =
               GhEx.GraphQL.query(client(__MODULE__.TelOK), "query { viewer { login } }")

      assert_received {:telemetry, [:gh_ex, :graphql, :start], _m, %{operation: :graphql}}

      assert_received {:telemetry, [:gh_ex, :graphql, :stop], stop_m, meta}
      assert is_integer(stop_m.duration)
      assert meta.result == :ok
      assert meta.status == 200
      assert meta.rate_limit.remaining == 4999
      assert meta.cost == %{"cost" => 1}
    end

    test "stop carries result: :error on a 200-with-errors body" do
      Req.Test.stub(__MODULE__.TelErr, fn conn ->
        Req.Test.json(conn, %{"data" => nil, "errors" => [%{"message" => "boom"}]})
      end)

      assert {:error, %GhEx.Error{}} =
               GhEx.GraphQL.query(client(__MODULE__.TelErr), "query { viewer { login } }")

      assert_received {:telemetry, [:gh_ex, :graphql, :stop], _m, meta}
      assert meta.result == :error
      assert %GhEx.Error{} = meta.error
    end
  end
end
