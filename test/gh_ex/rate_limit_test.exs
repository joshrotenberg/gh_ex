defmodule GhEx.RateLimitTest do
  use ExUnit.Case, async: true

  defp resp(status, headers \\ %{}, body \\ "") do
    %Req.Response{status: status, headers: headers, body: body}
  end

  defp snap(remaining, reset), do: %GhEx.RateLimit{remaining: remaining, reset: reset}

  describe "retry/2" do
    test "retries transient server errors" do
      for status <- [408, 500, 502, 503, 504] do
        assert GhEx.RateLimit.retry(%Req.Request{}, resp(status)) == true
      end
    end

    test "delays by retry-after when present" do
      assert {:delay, 2000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(429, %{"retry-after" => ["2"]}))
    end

    test "delays until x-ratelimit-reset when remaining is 0" do
      reset = System.system_time(:second) + 30

      r = resp(403, %{"x-ratelimit-remaining" => ["0"], "x-ratelimit-reset" => ["#{reset}"]})

      assert {:delay, ms} = GhEx.RateLimit.retry(%Req.Request{}, r)
      assert ms > 0 and ms <= 30_000
    end

    # The :retry step runs before :decode_body, so in production the body is the
    # raw JSON string, not a map. These use a string body to match that; see the
    # end-to-end pipeline test in rest_test.exs.
    test "delays a body-only secondary rate limit 403 by the recommended minimum" do
      body = ~s({"message":"You have exceeded a secondary rate limit. Please wait."})

      assert {:delay, 60_000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{}, body))
    end

    test "secondary rate limit detection is case-insensitive" do
      body = ~s({"message":"You have exceeded a SECONDARY RATE LIMIT."})

      assert {:delay, 60_000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{}, body))
    end

    test "also detects an already-decoded (map) body" do
      body = %{"message" => "You have exceeded a secondary rate limit."}

      assert {:delay, 60_000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{}, body))
    end

    test "retry-after takes precedence over the secondary rate limit body" do
      body = ~s({"message":"You have exceeded a secondary rate limit."})

      assert {:delay, 5000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{"retry-after" => ["5"]}, body))
    end

    test "does not retry a plain 403 or other non-retryable statuses" do
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(403)) == false
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(404)) == false
    end

    test "does not treat an unrelated 403 body message as a rate limit" do
      body = ~s({"message":"Resource not accessible by integration"})
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{}, body)) == false
    end

    test "does not retry exceptions" do
      assert GhEx.RateLimit.retry(%Req.Request{}, %RuntimeError{}) == false
    end
  end

  describe "delay_until_reset/2" do
    @now ~U[2026-06-29 00:00:00Z]

    test "returns the ms until reset when the bucket is exhausted" do
      assert GhEx.RateLimit.delay_until_reset(snap(0, DateTime.add(@now, 30, :second)), now: @now) ==
               30_000
    end

    test "returns 0 when remaining is above the floor" do
      assert GhEx.RateLimit.delay_until_reset(snap(100, DateTime.add(@now, 30, :second)),
               floor: 50,
               now: @now
             ) == 0
    end

    test "waits at the floor boundary (remaining == floor) but not just above it" do
      reset = DateTime.add(@now, 30, :second)
      assert GhEx.RateLimit.delay_until_reset(snap(50, reset), floor: 50, now: @now) == 30_000
      assert GhEx.RateLimit.delay_until_reset(snap(51, reset), floor: 50, now: @now) == 0
    end

    test "adds :buffer_ms to a non-zero wait" do
      assert GhEx.RateLimit.delay_until_reset(snap(0, DateTime.add(@now, 30, :second)),
               now: @now,
               buffer_ms: 1_000
             ) == 31_000
    end

    test "clamps an already-past reset to 0" do
      assert GhEx.RateLimit.delay_until_reset(snap(0, DateTime.add(@now, -10, :second)),
               now: @now
             ) ==
               0
    end

    test "returns 0 for a nil snapshot or absent remaining/reset" do
      assert GhEx.RateLimit.delay_until_reset(nil, now: @now) == 0
      assert GhEx.RateLimit.delay_until_reset(snap(nil, nil), now: @now) == 0
      assert GhEx.RateLimit.delay_until_reset(snap(0, nil), now: @now) == 0

      assert GhEx.RateLimit.delay_until_reset(snap(nil, DateTime.add(@now, 30, :second)),
               now: @now
             ) ==
               0
    end

    test "defaults the floor to 0: any remaining above zero is headroom" do
      reset = DateTime.add(@now, 30, :second)
      assert GhEx.RateLimit.delay_until_reset(snap(1, reset), now: @now) == 0
      assert GhEx.RateLimit.delay_until_reset(snap(0, reset), now: @now) == 30_000
    end
  end
end
