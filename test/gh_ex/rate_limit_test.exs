defmodule GhEx.RateLimitTest do
  use ExUnit.Case, async: true

  defp resp(status, headers \\ %{}, body \\ "") do
    %Req.Response{status: status, headers: headers, body: body}
  end

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

    test "delays a body-only secondary rate limit 403 by the recommended minimum" do
      body = %{"message" => "You have exceeded a secondary rate limit. Please wait."}

      assert {:delay, 60_000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{}, body))
    end

    test "secondary rate limit detection is case-insensitive" do
      body = %{"message" => "You have exceeded a SECONDARY RATE LIMIT."}

      assert {:delay, 60_000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{}, body))
    end

    test "retry-after takes precedence over the secondary rate limit body" do
      body = %{"message" => "You have exceeded a secondary rate limit."}

      assert {:delay, 5000} =
               GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{"retry-after" => ["5"]}, body))
    end

    test "does not retry a plain 403 or other non-retryable statuses" do
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(403)) == false
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(404)) == false
    end

    test "does not treat an unrelated 403 body message as a rate limit" do
      body = %{"message" => "Resource not accessible by integration"}
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(403, %{}, body)) == false
    end

    test "does not retry exceptions" do
      assert GhEx.RateLimit.retry(%Req.Request{}, %RuntimeError{}) == false
    end
  end
end
