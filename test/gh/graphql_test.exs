defmodule GH.GraphQLTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GH.new(auth: {:token, "secret"}, req_options: [plug: {Req.Test, stub}])
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
               GH.GraphQL.query(client(__MODULE__.OK), "query { viewer { login } }")

      assert data == %{"viewer" => %{"login" => "josh"}}
      assert meta.status == 200
    end

    test "passes variables through in the envelope" do
      Req.Test.stub(__MODULE__.Vars, fn conn ->
        assert %{"variables" => %{"login" => "josh"}} = decode_body(conn)
        Req.Test.json(conn, %{"data" => %{"user" => %{"name" => "Josh"}}})
      end)

      assert {:ok, %{"user" => %{"name" => "Josh"}}, _meta} =
               GH.GraphQL.query(
                 client(__MODULE__.Vars),
                 "query($login: String!) { user(login: $login) { name } }",
                 login: "josh"
               )
    end

    test "normalizes a 200-with-errors body into a GH.Error, preserving partial data" do
      Req.Test.stub(__MODULE__.Err, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"viewer" => nil},
          "errors" => [%{"message" => "Bad credentials", "type" => "FORBIDDEN"}]
        })
      end)

      assert {:error, %GH.Error{} = err} =
               GH.GraphQL.query(client(__MODULE__.Err), "query { viewer { login } }")

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
               GH.GraphQL.query(client(__MODULE__.EmptyErr), "query { viewer { login } }")
    end

    test "exposes the rateLimit cost block on meta when selected" do
      Req.Test.stub(__MODULE__.Cost, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"rateLimit" => %{"cost" => 1, "remaining" => 4999}}
        })
      end)

      assert {:ok, _data, meta} =
               GH.GraphQL.query(client(__MODULE__.Cost), "query { rateLimit { cost remaining } }")

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
        |> GH.GraphQL.stream(
          "query($org: String!, $cursor: String) { ... }",
          [org: "joshrotenberg"],
          path: ["organization", "projectsV2"]
        )
        |> Stream.map(& &1["title"])
        |> Enum.to_list()

      assert titles == ["A", "B", "C"]
    end

    test "raises GH.Error when a page returns GraphQL errors" do
      Req.Test.stub(__MODULE__.StreamErr, fn conn ->
        Req.Test.json(conn, %{"data" => nil, "errors" => [%{"message" => "boom"}]})
      end)

      assert_raise GH.Error, ~r/boom/, fn ->
        client(__MODULE__.StreamErr)
        |> GH.GraphQL.stream("query { ... }", path: ["x"])
        |> Enum.to_list()
      end
    end
  end
end
