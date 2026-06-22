defmodule GH.AppTest do
  use ExUnit.Case, async: true

  setup_all do
    private = :public_key.generate_key({:rsa, 2048, 65_537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, private)])
    %{pem: pem}
  end

  defp app(stub, pem) do
    GH.new(auth: {:app, "Iv1.app", pem}, req_options: [plug: {Req.Test, stub}])
  end

  describe "installation_token/3" do
    test "POSTs to the access_tokens endpoint with a JWT bearer", %{pem: pem} do
      Req.Test.stub(__MODULE__.Tok, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/app/installations/42/access_tokens"
        assert ["Bearer " <> jwt] = Plug.Conn.get_req_header(conn, "authorization")
        assert [_h, _c, _s] = String.split(jwt, ".")

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"token" => "ghs_abc", "expires_at" => "2026-06-22T21:00:00Z"})
      end)

      assert {:ok, body} = GH.App.installation_token(app(__MODULE__.Tok, pem), 42)
      assert body["token"] == "ghs_abc"
      assert body["expires_at"] == "2026-06-22T21:00:00Z"
    end

    test "scopes the token when :json is given", %{pem: pem} do
      Req.Test.stub(__MODULE__.Scoped, fn conn ->
        {:ok, raw, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"repositories" => ["gh_ex"]}

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"token" => "ghs_scoped", "expires_at" => "2026-06-22T21:00:00Z"})
      end)

      assert {:ok, %{"token" => "ghs_scoped"}} =
               GH.App.installation_token(app(__MODULE__.Scoped, pem), 42,
                 json: %{repositories: ["gh_ex"]}
               )
    end

    test "surfaces an API error", %{pem: pem} do
      Req.Test.stub(__MODULE__.Err, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Not Found"})
      end)

      assert {:error, %GH.Error{status: 404}} =
               GH.App.installation_token(app(__MODULE__.Err, pem), 99)
    end
  end

  describe "installation_client/3" do
    test "returns a token-auth client and expires_at, preserving req_options", %{pem: pem} do
      Req.Test.stub(__MODULE__.Cli, fn conn ->
        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"token" => "ghs_xyz", "expires_at" => "2026-06-22T21:00:00Z"})
      end)

      assert {:ok, client, expires_at} =
               GH.App.installation_client(app(__MODULE__.Cli, pem), 42)

      assert client.auth == {:token, "ghs_xyz"}
      assert expires_at == "2026-06-22T21:00:00Z"
      assert client.req_options == [plug: {Req.Test, __MODULE__.Cli}]
    end
  end
end
