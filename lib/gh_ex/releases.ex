defmodule GhEx.Releases do
  @moduledoc """
  Convenience functions for the GitHub Releases REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @type id :: integer() | String.t()
  @type asset :: %{
          required(:name) => String.t(),
          required(:content_type) => String.t(),
          required(:data) => iodata(),
          optional(:label) => String.t()
        }

  @doc "Lists releases for a repository."
  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases", opts)
  end

  @doc "Auto-paginates a repository's releases into a lazy `Stream` (see `GhEx.REST.stream/3`)."
  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/releases", opts)
  end

  @doc "Gets a release by id."
  @spec get(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get(client, owner, repo, id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases/#{id}", opts)
  end

  @doc "Gets the latest published release."
  @spec get_latest(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_latest(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases/latest", opts)
  end

  @doc "Gets a release by tag name."
  @spec get_by_tag(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_by_tag(client, owner, repo, tag, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/releases/tags/#{tag}", opts)
  end

  @doc "Creates a release. `attrs` is the JSON body (tag_name, name, body, draft, prerelease, ...)."
  @spec create(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/releases", Keyword.put(opts, :json, attrs))
  end

  @doc """
  Uploads raw asset data to a release's dedicated upload endpoint.

  The `asset` map requires `:name`, `:content_type`, and raw `:data`; `:label` is
  optional. GitHub.com uploads use `uploads.github.com`, while a GitHub Enterprise
  Server client whose REST URL ends in `/api/v3` uses `/api/uploads` on the same
  origin.

  To use the hypermedia URL returned by GitHub when creating or fetching a
  release, pass it as `upload_url: release["upload_url"]`. URI-template suffixes
  such as `{?name,label}` are removed automatically.

  The wrapper owns the request body, `name`/`label` query parameters, and
  `Content-Type` header. Other `opts` pass through to `Req`.
  """
  @spec upload_asset(Client.t(), String.t(), String.t(), id(), asset(), keyword()) ::
          REST.result()
  def upload_asset(client, owner, repo, release_id, asset, opts \\ []) do
    {upload_url, opts} =
      Keyword.pop_lazy(opts, :upload_url, fn ->
        default_upload_url(client, owner, repo, release_id)
      end)

    REST.post(client, strip_uri_template(upload_url), upload_options(asset, opts))
  end

  @doc """
  Generates a release name and Markdown body without saving a release.

  `attrs` must contain `tag_name` and may include `target_commitish`,
  `previous_tag_name`, or `configuration_file_path`.
  """
  @spec generate_release_notes(Client.t(), String.t(), String.t(), map(), keyword()) ::
          REST.result()
  def generate_release_notes(client, owner, repo, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/releases/generate-notes",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Updates a release."
  @spec update(Client.t(), String.t(), String.t(), id(), map(), keyword()) :: REST.result()
  def update(client, owner, repo, id, attrs, opts \\ []) do
    REST.patch(client, "/repos/#{owner}/#{repo}/releases/#{id}", Keyword.put(opts, :json, attrs))
  end

  @doc "Deletes a release."
  @spec delete(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def delete(client, owner, repo, id, opts \\ []) do
    REST.delete(client, "/repos/#{owner}/#{repo}/releases/#{id}", opts)
  end

  defp upload_options(asset, opts) do
    params =
      opts
      |> Keyword.get(:params, %{})
      |> Map.new()
      |> Map.drop([:name, "name", :label, "label"])
      |> Map.put(:name, Map.fetch!(asset, :name))
      |> maybe_put_label(Map.get(asset, :label))

    headers =
      opts
      |> Keyword.get(:headers, [])
      |> Enum.reject(fn {name, _value} -> String.downcase(to_string(name)) == "content-type" end)
      |> then(&[{"content-type", Map.fetch!(asset, :content_type)} | &1])

    opts
    |> Keyword.delete(:json)
    |> Keyword.put(:params, params)
    |> Keyword.put(:headers, headers)
    |> Keyword.put(:body, Map.fetch!(asset, :data))
  end

  defp maybe_put_label(params, nil), do: params
  defp maybe_put_label(params, label), do: Map.put(params, :label, label)

  defp default_upload_url(client, owner, repo, release_id) do
    uri = URI.parse(client.rest_url)
    rest_path = String.trim_trailing(uri.path || "", "/")

    upload_uri =
      cond do
        String.starts_with?(uri.host || "", "api.") and rest_path == "" ->
          %{uri | host: String.replace_prefix(uri.host, "api.", "uploads."), path: ""}

        String.ends_with?(rest_path, "/api/v3") ->
          %{uri | path: String.replace_suffix(rest_path, "/api/v3", "/api/uploads")}

        true ->
          %{uri | path: rest_path <> "/uploads"}
      end

    path = "#{upload_uri.path}/repos/#{owner}/#{repo}/releases/#{release_id}/assets"
    URI.to_string(%{upload_uri | path: path, query: nil, fragment: nil})
  end

  defp strip_uri_template(url), do: String.replace(url, ~r/\{[^}]+\}\z/, "")
end
