defmodule GhEx.OrganizationsTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  defp body(conn) do
    {:ok, raw, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(raw)
  end

  test "get/2 GETs an organization" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/orgs/acme"
      Req.Test.json(conn, %{"login" => "acme"})
    end)

    assert {:ok, %{"login" => "acme"}, _} =
             GhEx.Organizations.get(client(__MODULE__.Get), "acme")
  end

  test "list_for_authenticated_user/1 GETs orgs for the authenticated user" do
    Req.Test.stub(__MODULE__.ListForUser, fn conn ->
      assert conn.request_path == "/user/orgs"
      Req.Test.json(conn, [%{"login" => "acme"}])
    end)

    assert {:ok, [%{"login" => "acme"}], _} =
             GhEx.Organizations.list_for_authenticated_user(client(__MODULE__.ListForUser))
  end

  test "update/3 PATCHes an organization" do
    Req.Test.stub(__MODULE__.Update, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/orgs/acme"
      assert body(conn) == %{"description" => "new desc"}
      Req.Test.json(conn, %{"login" => "acme", "description" => "new desc"})
    end)

    assert {:ok, %{"login" => "acme"}, _} =
             GhEx.Organizations.update(client(__MODULE__.Update), "acme", %{
               description: "new desc"
             })
  end

  test "list_members/2 GETs members of an organization" do
    Req.Test.stub(__MODULE__.Members, fn conn ->
      assert conn.request_path == "/orgs/acme/members"
      Req.Test.json(conn, [%{"login" => "alice"}])
    end)

    assert {:ok, [%{"login" => "alice"}], _} =
             GhEx.Organizations.list_members(client(__MODULE__.Members), "acme")
  end
end
