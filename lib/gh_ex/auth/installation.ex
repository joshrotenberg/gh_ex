defmodule GhEx.Auth.Installation do
  @moduledoc false
  # Resolves an installation credential to a bearer token, minting through the
  # configured GhEx.TokenCache and re-minting transparently when the cached token
  # nears expiry. Built by GhEx.App.installation/3 and consumed by GhEx.Auth.resolve/1.

  @spec token(map()) :: {:ok, String.t()} | {:error, term()}
  def token(%{app: app, id: id, cache: cache} = spec) do
    {mod, ref} = normalize(cache)
    token_opts = Map.get(spec, :token_opts, [])
    key = {:gh_installation_token, app.rest_url, id, token_opts}
    mint = fn -> mint(app, id, token_opts) end

    case mod.fetch(ref, key, mint) do
      {:ok, %{token: token}} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp mint(app, id, token_opts) do
    case GhEx.App.installation_token(app, id, token_opts) do
      {:ok, %{"token" => token, "expires_at" => expires_at}} ->
        case DateTime.from_iso8601(expires_at) do
          {:ok, datetime, _offset} -> {:ok, %{token: token, expires_at: datetime}}
          _ -> {:error, {:invalid_expires_at, expires_at}}
        end

      {:ok, body} ->
        {:error, {:unexpected_response, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize({mod, ref}) when is_atom(mod), do: {mod, ref}
  defp normalize(mod) when is_atom(mod), do: {mod, mod}
end
