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

  test "stream/3 refuses a cross-host rel=next and never authenticates that host" do
    stub = __MODULE__.CrossHost
    test_pid = self()

    Req.Test.stub(stub, fn conn ->
      if conn.host == "evil.example", do: send(test_pid, {:requested, conn.host})

      conn
      |> Plug.Conn.put_resp_header("link", ~s(<https://evil.example/items?page=2>; rel="next"))
      |> Req.Test.json([%{"n" => 1}])
    end)

    client = GhEx.new(auth: {:token, "secret"}, req_options: [plug: {Req.Test, stub}])

    assert_raise GhEx.Error, ~r/refused cross-host pagination URL: evil\.example/, fn ->
      client |> GhEx.REST.stream("/items") |> Enum.to_list()
    end

    refute_received {:requested, "evil.example"}
  end

  test "stream/3 paginates normally under a non-default GHE rest_url" do
    stub = __MODULE__.GHE

    Req.Test.stub(stub, fn conn ->
      assert conn.host == "ghe.example"

      case conn.query_string do
        "page=2" ->
          Req.Test.json(conn, [%{"n" => 2}])

        _ ->
          conn
          |> Plug.Conn.put_resp_header(
            "link",
            ~s(<https://ghe.example/api/v3/items?page=2>; rel="next")
          )
          |> Req.Test.json([%{"n" => 1}])
      end
    end)

    client =
      GhEx.new(
        auth: {:token, "secret"},
        rest_url: "https://ghe.example/api/v3",
        req_options: [plug: {Req.Test, stub}]
      )

    items = client |> GhEx.REST.stream("/items") |> Enum.to_list()

    assert items == [%{"n" => 1}, %{"n" => 2}]
  end

  defp page_two_url(conn) do
    "#{conn.scheme}://#{conn.host}#{conn.request_path}?page=2"
  end
end
