defmodule GhEx.RESTTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "secret"}, req_options: [plug: {Req.Test, stub}])
  end

  describe "get/3" do
    test "returns {:ok, body, meta} on success and injects auth + version headers" do
      Req.Test.stub(__MODULE__.OK, fn conn ->
        assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
        assert ["2022-11-28"] = Plug.Conn.get_req_header(conn, "x-github-api-version")
        assert ["application/vnd.github+json"] = Plug.Conn.get_req_header(conn, "accept")
        assert ["gh_ex/" <> _version] = Plug.Conn.get_req_header(conn, "user-agent")
        Req.Test.json(conn, %{"full_name" => "elixir-lang/elixir"})
      end)

      assert {:ok, body, meta} = GhEx.REST.get(client(__MODULE__.OK), "/repos/elixir-lang/elixir")
      assert body["full_name"] == "elixir-lang/elixir"
      assert meta.status == 200
    end

    test "passes :params through as query string" do
      Req.Test.stub(__MODULE__.Params, fn conn ->
        assert conn.query_string == "state=open"
        Req.Test.json(conn, [])
      end)

      assert {:ok, [], _meta} =
               GhEx.REST.get(client(__MODULE__.Params), "/repos/o/r/issues",
                 params: [state: "open"]
               )
    end

    test "normalizes a 4xx into a GhEx.Error" do
      Req.Test.stub(__MODULE__.NotFound, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Not Found", "documentation_url" => "https://docs"})
      end)

      assert {:error, %GhEx.Error{} = err} = GhEx.REST.get(client(__MODULE__.NotFound), "/nope")
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
               GhEx.REST.post(client(__MODULE__.Post), "/repos/o/r/issues", json: %{title: "Bug"})

      assert body["number"] == 1
      assert meta.status == 201
    end
  end

  describe "patch/3, put/3, delete/3" do
    test "patch/3 sends a PATCH with a JSON body" do
      Req.Test.stub(__MODULE__.Patch, fn conn ->
        assert conn.method == "PATCH"
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"state" => "closed"}
        Req.Test.json(conn, %{"state" => "closed"})
      end)

      assert {:ok, %{"state" => "closed"}, meta} =
               GhEx.REST.patch(client(__MODULE__.Patch), "/repos/o/r/issues/1",
                 json: %{state: "closed"}
               )

      assert meta.status == 200
    end

    test "put/3 sends a PUT" do
      Req.Test.stub(__MODULE__.Put, fn conn ->
        assert conn.method == "PUT"

        conn
        |> Plug.Conn.put_status(200)
        |> Req.Test.json(%{"ok" => true})
      end)

      assert {:ok, %{"ok" => true}, _meta} =
               GhEx.REST.put(client(__MODULE__.Put), "/repos/o/r/subscription",
                 json: %{subscribed: true}
               )
    end

    test "delete/3 sends a DELETE and handles a 204 with an empty body" do
      Req.Test.stub(__MODULE__.Delete, fn conn ->
        assert conn.method == "DELETE"
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok, body, meta} =
               GhEx.REST.delete(client(__MODULE__.Delete), "/repos/o/r/issues/1/labels/bug")

      assert meta.status == 204
      assert body in ["", nil]
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

      assert {:ok, _body, meta} = GhEx.REST.get(client(__MODULE__.RL), "/x")
      assert meta.rate_limit.limit == 5000
      assert meta.rate_limit.remaining == 4998
      assert meta.rate_limit.used == 2
      assert meta.rate_limit.reset == ~U[2023-11-14 22:13:20Z]
    end

    test "rate_limit is nil when no rate-limit headers are present" do
      Req.Test.stub(__MODULE__.NoRL, fn conn -> Req.Test.json(conn, %{}) end)

      assert {:ok, _body, meta} = GhEx.REST.get(client(__MODULE__.NoRL), "/x")
      assert meta.rate_limit == nil
    end
  end

  describe "rate-limit retry" do
    test "GhEx.RateLimit.retry retries a 403 secondary rate limit, then succeeds" do
      {:ok, calls} = Agent.start_link(fn -> 0 end)

      Req.Test.stub(__MODULE__.Retry, fn conn ->
        n = Agent.get_and_update(calls, fn n -> {n, n + 1} end)

        if n == 0 do
          conn
          |> Plug.Conn.put_resp_header("retry-after", "0")
          |> Plug.Conn.put_status(403)
          |> Req.Test.json(%{"message" => "You have exceeded a secondary rate limit"})
        else
          Req.Test.json(conn, %{"ok" => true})
        end
      end)

      client =
        GhEx.new(
          req_options: [plug: {Req.Test, __MODULE__.Retry}, retry: &GhEx.RateLimit.retry/2]
        )

      assert {:ok, %{"ok" => true}, _meta} = GhEx.REST.get(client, "/x")
      assert Agent.get(calls, & &1) == 2
    end

    test "a plain 403 (not a rate limit) is not retried" do
      Req.Test.stub(__MODULE__.Plain403, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{"message" => "Forbidden"})
      end)

      client =
        GhEx.new(
          req_options: [plug: {Req.Test, __MODULE__.Plain403}, retry: &GhEx.RateLimit.retry/2]
        )

      assert {:error, %GhEx.Error{status: 403}} = GhEx.REST.get(client, "/x")
    end
  end
end
