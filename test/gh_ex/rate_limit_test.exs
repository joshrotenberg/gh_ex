defmodule GhEx.RateLimitTest do
  use ExUnit.Case, async: true

  defp resp(status, headers \\ %{}) do
    %Req.Response{status: status, headers: headers, body: ""}
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

    test "does not retry a plain 403 or other non-retryable statuses" do
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(403)) == false
      assert GhEx.RateLimit.retry(%Req.Request{}, resp(404)) == false
    end

    test "does not retry exceptions" do
      assert GhEx.RateLimit.retry(%Req.Request{}, %RuntimeError{}) == false
    end
  end
end
