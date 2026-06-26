defmodule GhEx.Contents do
  @moduledoc """
  Convenience functions for the GitHub repository Contents REST API (reading and
  writing files).

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`. The write endpoints
  take the GitHub body as-is: `content` must be Base64-encoded, and an update
  needs the blob `sha`.
  """

  alias GhEx.{Client, REST}

  @doc """
  Gets the contents of a file or directory. Use `params: [ref: "..."]` to select
  a branch, tag, or commit.
  """
  @spec get(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get(client, owner, repo, path, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/contents/#{encode_path(path)}", opts)
  end

  @doc """
  Creates or updates a file. `attrs` is the JSON body: `message`, `content`
  (Base64-encoded), `sha` (required when updating an existing file), and an
  optional `branch`.
  """
  @spec create_or_update_file(Client.t(), String.t(), String.t(), String.t(), map(), keyword()) ::
          REST.result()
  def create_or_update_file(client, owner, repo, path, attrs, opts \\ []) do
    REST.put(
      client,
      "/repos/#{owner}/#{repo}/contents/#{encode_path(path)}",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc """
  Deletes a file. `attrs` is the JSON body: `message`, the blob `sha`, and an
  optional `branch`.
  """
  @spec delete_file(Client.t(), String.t(), String.t(), String.t(), map(), keyword()) ::
          REST.result()
  def delete_file(client, owner, repo, path, attrs, opts \\ []) do
    REST.delete(
      client,
      "/repos/#{owner}/#{repo}/contents/#{encode_path(path)}",
      Keyword.put(opts, :json, attrs)
    )
  end

  # Req does not encode an already-built URL string, so a raw `path` with a
  # space, `#`, or `?` produces an invalid or wrong target. Split on `/` to keep
  # the path hierarchy, percent-encode each segment (leaving only the unreserved
  # set A-Z a-z 0-9 - _ . ~ literal), and rejoin.
  defp encode_path(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", &URI.encode(&1, fn c -> URI.char_unreserved?(c) end))
  end
end
