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

    # Regression: Req runs the :retry step before :decode_body, so the retry
    # function sees the raw (binary) body, not a decoded map. A body-only
    # secondary rate limit (no retry-after, remaining not 0) must still be
    # detected end-to-end. A spy captures the verdict on the real response and
    # returns false, so the test asserts the contract without sleeping 60s.
    test "detects a body-only secondary rate limit through the real Req pipeline" do
      test = self()

      Req.Test.stub(__MODULE__.SecondaryBody, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{"message" => "You have exceeded a secondary rate limit. Please wait."})
      end)

      spy = fn request, response ->
        send(test, {:verdict, GhEx.RateLimit.retry(request, response), response.body})
        false
      end

      client = GhEx.new(req_options: [plug: {Req.Test, __MODULE__.SecondaryBody}, retry: spy])

      GhEx.REST.get(client, "/x")

      assert_received {:verdict, verdict, body}
      assert is_binary(body), "the :retry step runs before :decode_body, so body is raw"
      assert verdict == {:delay, 60_000}
    end
  end

  describe "conditional requests" do
    test "exposes :etag and :last_modified on a 2xx meta" do
      Req.Test.stub(__MODULE__.Validators, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("etag", ~s("abc123"))
        |> Plug.Conn.put_resp_header("last-modified", "Mon, 01 Jan 2024 00:00:00 GMT")
        |> Req.Test.json(%{"ok" => true})
      end)

      assert {:ok, _body, meta} = GhEx.REST.get(client(__MODULE__.Validators), "/repos/o/r")
      assert meta.etag == ~s("abc123")
      assert meta.last_modified == "Mon, 01 Jan 2024 00:00:00 GMT"
    end

    test "leaves :etag and :last_modified nil when the headers are absent" do
      Req.Test.stub(__MODULE__.NoValidators, fn conn ->
        Req.Test.json(conn, %{"ok" => true})
      end)

      assert {:ok, _body, meta} = GhEx.REST.get(client(__MODULE__.NoValidators), "/repos/o/r")
      assert meta.etag == nil
      assert meta.last_modified == nil
    end

    test "returns {:ok, :not_modified, meta} on a 304 instead of an error" do
      Req.Test.stub(__MODULE__.NotModified, fn conn ->
        assert ["\"abc123\""] = Plug.Conn.get_req_header(conn, "if-none-match")

        conn
        |> Plug.Conn.put_resp_header("etag", ~s("abc123"))
        |> Plug.Conn.send_resp(304, "")
      end)

      assert {:ok, :not_modified, meta} =
               GhEx.REST.get(client(__MODULE__.NotModified), "/repos/o/r",
                 headers: [{"if-none-match", ~s("abc123")}]
               )

      assert meta.status == 304
      assert meta.etag == ~s("abc123")
    end
  end

  describe "raw/4" do
    test "returns the raw response and does not treat a non-2xx as an error" do
      Req.Test.stub(__MODULE__.Raw, fn conn ->
        case conn.request_path do
          "/ok" ->
            Req.Test.json(conn, %{"ok" => true})

          "/missing" ->
            conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{"message" => "Not Found"})
        end
      end)

      c = client(__MODULE__.Raw)
      assert {:ok, %Req.Response{status: 200}} = GhEx.REST.raw(c, :get, "/ok")
      assert {:ok, %Req.Response{status: 404}} = GhEx.REST.raw(c, :get, "/missing")
    end
  end

  describe "RateLimit.get/1" do
    test "GETs /rate_limit" do
      Req.Test.stub(__MODULE__.RLGet, fn conn ->
        assert conn.request_path == "/rate_limit"

        Req.Test.json(conn, %{"resources" => %{"core" => %{"limit" => 5000, "remaining" => 4999}}})
      end)

      assert {:ok, %{"resources" => %{"core" => %{"limit" => 5000}}}, _meta} =
               GhEx.RateLimit.get(client(__MODULE__.RLGet))
    end
  end

  describe "telemetry" do
    setup %{test: test} do
      events = [
        [:gh_ex, :request, :start],
        [:gh_ex, :request, :stop]
      ]

      :telemetry.attach_many(
        "#{test}",
        events,
        fn event, measurements, metadata, pid ->
          send(pid, {:telemetry, event, measurements, metadata})
        end,
        self()
      )

      on_exit(fn -> :telemetry.detach("#{test}") end)
    end

    test "emits start and stop with status and rate_limit on success" do
      Req.Test.stub(__MODULE__.TelOK, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "4999")
        |> Req.Test.json(%{"ok" => true})
      end)

      assert {:ok, _body, _meta} = GhEx.REST.get(client(__MODULE__.TelOK), "/tel-ok")

      assert_received {:telemetry, [:gh_ex, :request, :start], start_m,
                       %{method: :get, path: "/tel-ok"}}

      assert is_integer(start_m.system_time)

      # Match this test's own request by its unique path: the handler is global,
      # so in an async run it also receives request events from other modules.
      assert_received {:telemetry, [:gh_ex, :request, :stop], stop_m, %{path: "/tel-ok"} = meta}

      assert is_integer(stop_m.duration)
      assert meta.result == :ok
      assert meta.status == 200
      assert meta.rate_limit.remaining == 4999
    end

    test "stop carries result: :error and the reason on a failure" do
      Req.Test.stub(__MODULE__.TelErr, fn conn ->
        conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{"message" => "Not Found"})
      end)

      assert {:error, %GhEx.Error{}} = GhEx.REST.get(client(__MODULE__.TelErr), "/tel-err")

      assert_received {:telemetry, [:gh_ex, :request, :stop], _m, %{path: "/tel-err"} = meta}
      assert meta.result == :error
      assert %GhEx.Error{status: 404} = meta.error
    end
  end
end
