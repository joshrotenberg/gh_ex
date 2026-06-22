defmodule GH.RESTTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GH.new(auth: {:token, "secret"}, req_options: [plug: {Req.Test, stub}])
  end

  describe "get/3" do
    test "returns {:ok, body, meta} on success and injects auth + version headers" do
      Req.Test.stub(__MODULE__.OK, fn conn ->
        assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
        assert ["2022-11-28"] = Plug.Conn.get_req_header(conn, "x-github-api-version")
        assert ["application/vnd.github+json"] = Plug.Conn.get_req_header(conn, "accept")
        Req.Test.json(conn, %{"full_name" => "elixir-lang/elixir"})
      end)

      assert {:ok, body, meta} = GH.REST.get(client(__MODULE__.OK), "/repos/elixir-lang/elixir")
      assert body["full_name"] == "elixir-lang/elixir"
      assert meta.status == 200
    end

    test "passes :params through as query string" do
      Req.Test.stub(__MODULE__.Params, fn conn ->
        assert conn.query_string == "state=open"
        Req.Test.json(conn, [])
      end)

      assert {:ok, [], _meta} =
               GH.REST.get(client(__MODULE__.Params), "/repos/o/r/issues",
                 params: [state: "open"]
               )
    end

    test "normalizes a 4xx into a GH.Error" do
      Req.Test.stub(__MODULE__.NotFound, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Not Found", "documentation_url" => "https://docs"})
      end)

      assert {:error, %GH.Error{} = err} = GH.REST.get(client(__MODULE__.NotFound), "/nope")
      assert err.status == 404
      assert err.message == "Not Found"
      assert err.documentation_url == "https://docs"
      assert Exception.message(err) =~ "GitHub API error (HTTP 404): Not Found"
    end
  end

  describe "post/3" do
    test "sends a JSON body" do
      Req.Test.stub(__MODULE__.Post, fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"title" => "Bug"}

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"number" => 1})
      end)

      assert {:ok, body, meta} =
               GH.REST.post(client(__MODULE__.Post), "/repos/o/r/issues", json: %{title: "Bug"})

      assert body["number"] == 1
      assert meta.status == 201
    end
  end

  describe "meta" do
    test "parses rate-limit headers into a snapshot" do
      Req.Test.stub(__MODULE__.RL, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-limit", "5000")
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "4998")
        |> Plug.Conn.put_resp_header("x-ratelimit-used", "2")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset", "1700000000")
        |> Req.Test.json(%{})
      end)

      assert {:ok, _body, meta} = GH.REST.get(client(__MODULE__.RL), "/x")
      assert meta.rate_limit.limit == 5000
      assert meta.rate_limit.remaining == 4998
      assert meta.rate_limit.used == 2
      assert meta.rate_limit.reset == ~U[2023-11-14 22:13:20Z]
    end
  end
end
