defmodule GhEx.AppLiveTest do
  @moduledoc """
  Live smoke test for GitHub App auth against the real GitHub API.

  Excluded from the normal suite (tagged `:live`). It confirms what the offline
  tests cannot: that GitHub accepts the OTP-minted RS256 JWT and the installation
  token flow. Provide a GitHub App's credentials and run:

      export GH_EX_APP_ID=<app id or client id>
      export GH_EX_APP_PEM=/path/to/private-key.pem   # a file path, or the PEM contents
      # optional; auto-discovered from GET /app/installations when omitted:
      export GH_EX_INSTALLATION_ID=<installation id>

      mix test --only live

  The App needs only "Repository permissions -> Metadata: Read" and must be
  installed on at least one repository.
  """
  use ExUnit.Case, async: false

  @moduletag :live

  setup_all do
    app_id = require_env("GH_EX_APP_ID")
    pem = require_pem()
    {:ok, app: GhEx.new(auth: {:app, app_id, pem})}
  end

  test "GitHub accepts the minted App JWT (GET /app)", %{app: app} do
    assert {:ok, body, meta} = GhEx.REST.get(app, "/app")
    assert meta.status == 200
    assert body["id"]
  end

  test "mints an installation token and uses it", %{app: app} do
    id = installation_id(app)

    assert {:ok, %{"token" => token}} = GhEx.App.installation_token(app, id)
    assert is_binary(token)

    assert {:ok, inst, _expires_at} = GhEx.App.installation_client(app, id)
    assert {:ok, _repos, meta} = GhEx.REST.get(inst, "/installation/repositories")
    assert meta.status == 200
  end

  test "the transparent cache serves repeated installation requests", %{app: app} do
    start_supervised!({GhEx.TokenCache.ETS, name: __MODULE__.Cache})

    inst =
      GhEx.App.installation(app, installation_id(app),
        cache: {GhEx.TokenCache.ETS, __MODULE__.Cache}
      )

    assert {:ok, _, _} = GhEx.REST.get(inst, "/installation/repositories")
    assert {:ok, _, _} = GhEx.REST.get(inst, "/installation/repositories")
  end

  defp installation_id(app) do
    case System.get_env("GH_EX_INSTALLATION_ID") do
      nil ->
        assert {:ok, [%{"id" => id} | _], _meta} = GhEx.REST.get(app, "/app/installations")
        id

      id ->
        id
    end
  end

  defp require_env(name) do
    System.get_env(name) ||
      flunk("set #{name} to run the live App-auth test: mix test --only live")
  end

  defp require_pem do
    val = require_env("GH_EX_APP_PEM")
    if File.exists?(val), do: File.read!(val), else: val
  end
end
