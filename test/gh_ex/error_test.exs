defmodule GhEx.ErrorTest do
  use ExUnit.Case, async: true

  doctest GhEx.Error

  test "message/1 formats with and without a status and message" do
    assert Exception.message(%GhEx.Error{status: 404, message: "Not Found"}) ==
             "GitHub API error (HTTP 404): Not Found"

    assert Exception.message(%GhEx.Error{status: nil, message: nil}) == "GitHub API error"

    assert Exception.message(%GhEx.Error{status: nil, message: "boom"}) ==
             "GitHub API error: boom"
  end

  test "from_response/1 handles a non-map (e.g. HTML) body" do
    err =
      GhEx.Error.from_response(%Req.Response{
        status: 503,
        body: "<html>down</html>",
        headers: %{}
      })

    assert err.status == 503
    assert err.message == nil
    assert err.body == "<html>down</html>"
    assert err.errors == nil
  end

  test "from_response/1 preserves the response headers" do
    headers = %{"x-ratelimit-remaining" => ["0"]}
    err = GhEx.Error.from_response(%Req.Response{status: 403, body: %{}, headers: headers})

    assert err.headers == headers
  end

  describe "classify/1" do
    test "429 is rate_limited regardless of headers or body" do
      assert GhEx.Error.classify(%GhEx.Error{status: 429}) == :rate_limited
    end

    test "403 with retry-after is rate_limited" do
      err = %GhEx.Error{status: 403, headers: %{"retry-after" => ["2"]}}
      assert GhEx.Error.classify(err) == :rate_limited
    end

    test "403 with x-ratelimit-remaining: 0 is rate_limited" do
      err = %GhEx.Error{
        status: 403,
        headers: %{
          "x-ratelimit-remaining" => ["0"],
          "x-ratelimit-reset" => ["#{System.system_time(:second) + 30}"]
        }
      }

      assert GhEx.Error.classify(err) == :rate_limited
    end

    test "403 with a secondary-rate-limit body message is rate_limited" do
      err = %GhEx.Error{
        status: 403,
        body: ~s({"message":"You have exceeded a secondary rate limit. Please wait."})
      }

      assert GhEx.Error.classify(err) == :rate_limited
    end

    test "403 with a secondary-rate-limit message in an already-decoded body is rate_limited" do
      err = %GhEx.Error{
        status: 403,
        body: %{"message" => "You have exceeded a secondary rate limit."}
      }

      assert GhEx.Error.classify(err) == :rate_limited
    end

    test "a plain 403 (no rate-limit signal) is permission, not rate_limited" do
      err = %GhEx.Error{status: 403, message: "Resource not accessible by integration"}
      assert GhEx.Error.classify(err) == :permission
    end

    test "401 is permission" do
      assert GhEx.Error.classify(%GhEx.Error{status: 401}) == :permission
    end

    test "404 is not_found" do
      assert GhEx.Error.classify(%GhEx.Error{status: 404}) == :not_found
    end

    test "410 (gone) is not_found" do
      assert GhEx.Error.classify(%GhEx.Error{status: 410}) == :not_found
    end

    test "422 is validation" do
      assert GhEx.Error.classify(%GhEx.Error{status: 422}) == :validation
    end

    test "400 is validation" do
      assert GhEx.Error.classify(%GhEx.Error{status: 400}) == :validation
    end

    test "a nil status (GraphQL 200-with-errors) is validation" do
      err = GhEx.Error.from_graphql([%{"message" => "boom"}], nil)
      assert GhEx.Error.classify(err) == :validation
    end

    test "408 and 5xx are server" do
      for status <- [408, 500, 502, 503, 504, 501] do
        assert GhEx.Error.classify(%GhEx.Error{status: status}) == :server
      end
    end

    test "a raw transport exception is transport" do
      assert GhEx.Error.classify(%RuntimeError{message: "closed"}) == :transport
    end
  end

  describe "retryable?/1" do
    test "rate_limited errors are retryable" do
      assert GhEx.Error.retryable?(%GhEx.Error{status: 429})

      assert GhEx.Error.retryable?(%GhEx.Error{
               status: 403,
               headers: %{"retry-after" => ["2"]}
             })
    end

    test "transient server statuses are retryable" do
      for status <- [408, 500, 502, 503, 504] do
        assert GhEx.Error.retryable?(%GhEx.Error{status: status})
      end
    end

    test "an unlisted 5xx is not retryable, consistent with retry/2" do
      refute GhEx.Error.retryable?(%GhEx.Error{status: 501})
    end

    test "permission, not_found, and validation errors are not retryable" do
      refute GhEx.Error.retryable?(%GhEx.Error{status: 403})
      refute GhEx.Error.retryable?(%GhEx.Error{status: 401})
      refute GhEx.Error.retryable?(%GhEx.Error{status: 404})
      refute GhEx.Error.retryable?(%GhEx.Error{status: 410})
      refute GhEx.Error.retryable?(%GhEx.Error{status: 422})
    end

    test "a raw transport exception is not retryable, consistent with retry/2" do
      refute GhEx.Error.retryable?(%RuntimeError{})
    end
  end
end
