defmodule GhEx.TokenCache.ETSTest do
  use ExUnit.Case, async: false

  alias GhEx.TokenCache.ETS

  setup do
    pid = start_supervised!({ETS, name: __MODULE__.Cache})
    %{cache: __MODULE__.Cache, pid: pid}
  end

  defp value(token, seconds_from_now) do
    %{token: token, expires_at: DateTime.add(DateTime.utc_now(), seconds_from_now)}
  end

  test "mints once and serves the cached value on later fetches", %{cache: cache} do
    counter = :counters.new(1, [])

    mint = fn ->
      :counters.add(counter, 1, 1)
      {:ok, value("fresh", 3600)}
    end

    assert {:ok, %{token: "fresh"}} = ETS.fetch(cache, :k, mint)
    assert {:ok, %{token: "fresh"}} = ETS.fetch(cache, :k, mint)
    assert {:ok, %{token: "fresh"}} = ETS.fetch(cache, :k, mint)
    assert :counters.get(counter, 1) == 1
  end

  test "re-mints when the cached token is within the refresh skew", %{cache: cache} do
    counter = :counters.new(1, [])

    # expires in 10s, inside the 60s refresh skew, so it is never considered fresh
    mint = fn ->
      :counters.add(counter, 1, 1)
      {:ok, value("stale", 10)}
    end

    assert {:ok, _} = ETS.fetch(cache, :k, mint)
    assert {:ok, _} = ETS.fetch(cache, :k, mint)
    assert :counters.get(counter, 1) == 2
  end

  test "caches keys independently", %{cache: cache} do
    assert {:ok, %{token: "a"}} = ETS.fetch(cache, :a, fn -> {:ok, value("a", 3600)} end)
    assert {:ok, %{token: "b"}} = ETS.fetch(cache, :b, fn -> {:ok, value("b", 3600)} end)
    # both still served from cache
    assert {:ok, %{token: "a"}} = ETS.fetch(cache, :a, fn -> flunk("should not re-mint") end)
    assert {:ok, %{token: "b"}} = ETS.fetch(cache, :b, fn -> flunk("should not re-mint") end)
  end

  test "propagates a mint error without caching it", %{cache: cache} do
    assert {:error, :boom} = ETS.fetch(cache, :k, fn -> {:error, :boom} end)
    # a later successful mint still works (the error was not stored)
    assert {:ok, %{token: "ok"}} = ETS.fetch(cache, :k, fn -> {:ok, value("ok", 3600)} end)
  end

  test "multiple named caches coexist under one supervisor" do
    {:ok, sup} =
      Supervisor.start_link(
        [{ETS, name: __MODULE__.A}, {ETS, name: __MODULE__.B}],
        strategy: :one_for_one
      )

    assert {:ok, %{token: "a"}} = ETS.fetch(__MODULE__.A, :k, fn -> {:ok, value("a", 3600)} end)
    assert {:ok, %{token: "b"}} = ETS.fetch(__MODULE__.B, :k, fn -> {:ok, value("b", 3600)} end)

    Supervisor.stop(sup)
  end
end
