defmodule GH.PaginationTest do
  use ExUnit.Case, async: true

  doctest GH.Pagination

  test "parse/1 reads next and last out of a Link header" do
    value =
      ~s(<https://api.github.com/x?page=2>; rel="next", <https://api.github.com/x?page=9>; rel="last")

    assert GH.Pagination.parse(value) == %{
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

    client = GH.new(req_options: [plug: {Req.Test, stub}])

    items =
      client
      |> GH.REST.stream("/items")
      |> Enum.to_list()

    assert items == [%{"n" => 1}, %{"n" => 2}, %{"n" => 3}, %{"n" => 4}]
  end

  defp page_two_url(conn) do
    "#{conn.scheme}://#{conn.host}#{conn.request_path}?page=2"
  end
end
