defmodule GhEx.TeamsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "list/2 GETs teams for an organization" do
    Req.Test.stub(__MODULE__.List, fn conn ->
      assert conn.request_path == "/orgs/acme/teams"
      Req.Test.json(conn, [%{"slug" => "eng"}])
    end)

    assert {:ok, [%{"slug" => "eng"}], _} =
             GhEx.Teams.list(client(__MODULE__.List), "acme")
  end

  test "get_by_slug/3 GETs a team by slug" do
    Req.Test.stub(__MODULE__.GetBySlug, fn conn ->
      assert conn.request_path == "/orgs/acme/teams/eng"
      Req.Test.json(conn, %{"slug" => "eng"})
    end)

    assert {:ok, %{"slug" => "eng"}, _} =
             GhEx.Teams.get_by_slug(client(__MODULE__.GetBySlug), "acme", "eng")
  end

  test "create/3 POSTs a new team" do
    Req.Test.stub(__MODULE__.Create, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/orgs/acme/teams"
      assert body(conn) == %{"name" => "ops"}
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"slug" => "ops"})
    end)

    assert {:ok, %{"slug" => "ops"}, _} =
             GhEx.Teams.create(client(__MODULE__.Create), "acme", %{name: "ops"})
  end

  test "list_members/3 GETs members of a team" do
    Req.Test.stub(__MODULE__.Members, fn conn ->
      assert conn.request_path == "/orgs/acme/teams/eng/members"
      Req.Test.json(conn, [%{"login" => "alice"}])
    end)

    assert {:ok, [%{"login" => "alice"}], _} =
             GhEx.Teams.list_members(client(__MODULE__.Members), "acme", "eng")
  end
end
