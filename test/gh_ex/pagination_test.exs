defmodule GhEx.PaginationTest do
  use ExUnit.Case, async: true

  doctest GhEx.Pagination

  test "parse/1 reads next and last out of a Link header" do
    value =
      ~s(<https://api.github.com/x?page=2>; rel="next", <https://api.github.com/x?page=9>; rel="last")

    assert GhEx.Pagination.parse(value) == %{
             "next" => "https://api.github.com/x?page=2",
             "last" => "https://api.github.com/x?page=9"
           }
  end

  test "stream/3 follows rel=next across pages and flattens items" do
    stub = __MODULE__.Pages

    Req.Test.stub(stub, fn conn ->
      case conn.query_string do
        "page=2" ->
          Req.Test.json(conn, [%{"n" => 3}, %{"n" => 4}])

        _ ->
          conn
          |> Plug.Conn.put_resp_header(
            "link",
            ~s(<#{page_two_url(conn)}>; rel="next")
          )
          |> Req.Test.json([%{"n" => 1}, %{"n" => 2}])
      end
    end)

    client = GhEx.new(req_options: [plug: {Req.Test, stub}])

    items =
      client
      |> GhEx.REST.stream("/items")
      |> Enum.to_list()

    assert items == [%{"n" => 1}, %{"n" => 2}, %{"n" => 3}, %{"n" => 4}]
  end

  test "stream/3 raises GhEx.Error when a page fails" do
    stub = __MODULE__.StreamErr

    Req.Test.stub(stub, fn conn ->
      case conn.query_string do
        "page=2" ->
          conn
          |> Plug.Conn.put_status(403)
          |> Req.Test.json(%{"message" => "Forbidden"})

        _ ->
          conn
          |> Plug.Conn.put_resp_header("link", ~s(<#{page_two_url(conn)}>; rel="next"))
          |> Req.Test.json([%{"n" => 1}])
      end
    end)

    client = GhEx.new(req_options: [plug: {Req.Test, stub}])

    assert_raise GhEx.Error, ~r/Forbidden/, fn ->
      client |> GhEx.REST.stream("/items") |> Enum.to_list()
    end
  end

  defp page_two_url(conn) do
    "#{conn.scheme}://#{conn.host}#{conn.request_path}?page=2"
  end
end
