defmodule GhEx.ErrorTest do
  use ExUnit.Case, async: true

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
end
