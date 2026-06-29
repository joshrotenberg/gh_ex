defmodule GhEx.UsersTest do
  use ExUnit.Case, async: true

  defp client(stub) do
    GhEx.new(auth: {:token, "t"}, req_options: [plug: {Req.Test, stub}])
  end

  test "get/2 GETs a user by username" do
    Req.Test.stub(__MODULE__.Get, fn conn ->
      assert conn.request_path == "/users/josh"
      Req.Test.json(conn, %{"login" => "josh"})
    end)

    assert {:ok, %{"login" => "josh"}, _} =
             GhEx.Users.get(client(__MODULE__.Get), "josh")
  end

  test "get_authenticated/1 GETs the authenticated user" do
    Req.Test.stub(__MODULE__.GetAuthenticated, fn conn ->
      assert conn.request_path == "/user"
      Req.Test.json(conn, %{"login" => "me"})
    end)

    assert {:ok, %{"login" => "me"}, _} =
             GhEx.Users.get_authenticated(client(__MODULE__.GetAuthenticated))
  end

  test "list_followers/2 GETs followers for a user" do
    Req.Test.stub(__MODULE__.Followers, fn conn ->
      assert conn.request_path == "/users/josh/followers"
      Req.Test.json(conn, [%{"login" => "alice"}])
    end)

    assert {:ok, [%{"login" => "alice"}], _} =
             GhEx.Users.list_followers(client(__MODULE__.Followers), "josh")
  end

  test "list_following/2 GETs users followed by a user" do
    Req.Test.stub(__MODULE__.Following, fn conn ->
      assert conn.request_path == "/users/josh/following"
      Req.Test.json(conn, [%{"login" => "bob"}])
    end)

    assert {:ok, [%{"login" => "bob"}], _} =
             GhEx.Users.list_following(client(__MODULE__.Following), "josh")
  end

  test "list_emails/1 GETs emails for the authenticated user" do
    Req.Test.stub(__MODULE__.Emails, fn conn ->
      assert conn.request_path == "/user/emails"
      Req.Test.json(conn, [%{"email" => "me@example.com"}])
    end)

    assert {:ok, [%{"email" => "me@example.com"}], _} =
             GhEx.Users.list_emails(client(__MODULE__.Emails))
  end

  test "stream_followers/3 auto-paginates a user's followers" do
    Req.Test.stub(__MODULE__.StreamFollowers, fn conn ->
      assert conn.request_path == "/users/josh/followers"
      Req.Test.json(conn, [%{"login" => "alice"}])
    end)

    assert client(__MODULE__.StreamFollowers)
           |> GhEx.Users.stream_followers("josh")
           |> Enum.to_list() == [%{"login" => "alice"}]
  end

  test "stream_following/3 auto-paginates who a user follows" do
    Req.Test.stub(__MODULE__.StreamFollowing, fn conn ->
      assert conn.request_path == "/users/josh/following"
      Req.Test.json(conn, [%{"login" => "bob"}])
    end)

    assert client(__MODULE__.StreamFollowing)
           |> GhEx.Users.stream_following("josh")
           |> Enum.to_list() == [%{"login" => "bob"}]
  end

  test "stream_emails/2 auto-paginates the authenticated user's emails" do
    Req.Test.stub(__MODULE__.StreamEmails, fn conn ->
      assert conn.request_path == "/user/emails"
      Req.Test.json(conn, [%{"email" => "me@example.com"}])
    end)

    assert client(__MODULE__.StreamEmails)
           |> GhEx.Users.stream_emails()
           |> Enum.to_list() == [%{"email" => "me@example.com"}]
  end
end
