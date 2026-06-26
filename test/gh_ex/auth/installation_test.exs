defmodule GhEx.Auth.InstallationTest do
  use ExUnit.Case, async: false

  setup_all do
    private = :public_key.generate_key({:rsa, 2048, 65_537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, private)])
    %{pem: pem}
  end

  setup do
    pid = start_supervised!({GhEx.TokenCache.ETS, name: __MODULE__.Cache})
    %{cache_pid: pid, cache: {GhEx.TokenCache.ETS, __MODULE__.Cache}}
  end

  defp future_iso do
    DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_iso8601()
  end

  test "transparently mints, caches, and authenticates installation requests",
       %{pem: pem, cache_pid: cache_pid, cache: cache} do
    mints = :counters.new(1, [])

    Req.Test.stub(__MODULE__.Stub, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/app/installations/7/access_tokens"} ->
          assert ["Bearer " <> jwt] = Plug.Conn.get_req_header(conn, "authorization")
          assert [_h, _c, _s] = String.split(jwt, ".")
          :counters.add(mints, 1, 1)

          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{"token" => "ghs_inst", "expires_at" => future_iso()})

        {"GET", "/installation/repositories"} ->
          assert ["Bearer ghs_inst"] = Plug.Conn.get_req_header(conn, "authorization")
          Req.Test.json(conn, %{"total_count" => 0, "repositories" => []})
      end
    end)

    # The mint runs inside the cache GenServer, so authorize it to use the stub.
    Req.Test.allow(__MODULE__.Stub, self(), cache_pid)

    app = GhEx.new(auth: {:app, "Iv1.app", pem}, req_options: [plug: {Req.Test, __MODULE__.Stub}])
    inst = GhEx.App.installation(app, 7, cache: cache)

    assert {:ok, %{"total_count" => 0}, _meta} = GhEx.REST.get(inst, "/installation/repositories")
    assert {:ok, %{"total_count" => 0}, _meta} = GhEx.REST.get(inst, "/installation/repositories")

    # Two requests, one mint: the token was cached after the first.
    assert :counters.get(mints, 1) == 1

    # The cached token is a redacting struct, so a crash dump of the ETS table
    # (or any inspect of it) never prints the token in cleartext.
    [{_key, value}] = :ets.tab2list(__MODULE__.Cache)
    assert %GhEx.TokenCache.Value{token: "ghs_inst"} = value
    refute inspect(value) =~ "ghs_inst"
    assert inspect(value) =~ "GhEx.TokenCache.Value"
  end

  test "surfaces a mint failure as the request result",
       %{pem: pem, cache_pid: cache_pid, cache: cache} do
    Req.Test.stub(__MODULE__.ErrStub, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{"message" => "Not Found"})
    end)

    Req.Test.allow(__MODULE__.ErrStub, self(), cache_pid)

    app =
      GhEx.new(auth: {:app, "Iv1.app", pem}, req_options: [plug: {Req.Test, __MODULE__.ErrStub}])

    inst = GhEx.App.installation(app, 99, cache: cache)

    assert {:error, %GhEx.Error{status: 404}} = GhEx.REST.get(inst, "/installation/repositories")
  end

  test "a malformed expires_at surfaces as an error instead of an infinite re-mint",
       %{pem: pem, cache_pid: cache_pid, cache: cache} do
    Req.Test.stub(__MODULE__.BadExp, fn conn ->
      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(%{"token" => "ghs_inst", "expires_at" => "not-a-date"})
    end)

    Req.Test.allow(__MODULE__.BadExp, self(), cache_pid)

    app =
      GhEx.new(auth: {:app, "Iv1.app", pem}, req_options: [plug: {Req.Test, __MODULE__.BadExp}])

    inst = GhEx.App.installation(app, 7, cache: cache)

    assert {:error, {:invalid_expires_at, "not-a-date"}} =
             GhEx.REST.get(inst, "/installation/repositories")
  end
end
