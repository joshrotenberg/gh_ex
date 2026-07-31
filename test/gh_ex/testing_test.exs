defmodule GhEx.TestingTest do
  use ExUnit.Case, async: true

  doctest GhEx.Testing

  test "client/1 installs the named stub and disables retries" do
    assert %GhEx.Client{
             req_options: [plug: {Req.Test, __MODULE__.Stub}, retry: false]
           } = GhEx.Testing.client(__MODULE__.Stub)
  end

  test "client/1 returns a stubbed transient failure without retrying" do
    Req.Test.expect(__MODULE__.NoRetry, 1, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.json(%{"message" => "Server Error"})
    end)

    assert {:error, %GhEx.Error{status: 500}} =
             GhEx.REST.get(GhEx.Testing.client(__MODULE__.NoRetry), "/test")
  end

  test "json/2 includes a parseable core rate-limit snapshot" do
    Req.Test.stub(__MODULE__.JSON, fn conn ->
      GhEx.Testing.json(conn, %{"ok" => true})
    end)

    assert {:ok, %{"ok" => true}, meta} =
             GhEx.REST.get(GhEx.Testing.client(__MODULE__.JSON), "/test")

    assert meta.rate_limit.limit == 5000
    assert meta.rate_limit.remaining == 4999
    assert meta.rate_limit.used == 1
    assert meta.rate_limit.resource == "core"
    assert meta.rate_limit.reset == ~U[2100-01-01 00:00:00Z]
  end

  test "not_modified/1 exercises the conditional-request result" do
    Req.Test.stub(__MODULE__.NotModified, &GhEx.Testing.not_modified/1)

    assert {:ok, :not_modified, %{status: 304}} =
             GhEx.REST.get(GhEx.Testing.client(__MODULE__.NotModified), "/test")
  end

  test "rate_limited/2 builds each supported classification shape" do
    for kind <- [:retry_after, :primary, :secondary] do
      stub = {__MODULE__, kind}
      Req.Test.stub(stub, fn conn -> GhEx.Testing.rate_limited(conn, kind) end)

      assert {:error, %GhEx.Error{} = error} =
               GhEx.REST.get(GhEx.Testing.client(stub), "/test")

      assert GhEx.Error.classify(error) == :rate_limited
      assert GhEx.Error.retryable?(error)
    end
  end
end
