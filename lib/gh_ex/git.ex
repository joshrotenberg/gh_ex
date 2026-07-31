defmodule GhEx.Git do
  @moduledoc """
  Convenience functions for GitHub's Git reference REST API.

  References identify branch heads and tags. Read and delete operations accept
  either a relative reference such as `"heads/main"` or a fully qualified one
  such as `"refs/heads/main"`. Create operations likewise accept either form
  in `attrs.ref` and send GitHub the required fully qualified `refs/...` value.

  These thin wrappers return the same `{:ok, body, meta}` / `{:error, reason}`
  shape as `GhEx.REST` and pass `opts` through to `Req`.
  """

  alias GhEx.{Client, REST}

  @doc """
  Gets one Git reference.

  `ref` is a branch or tag path such as `"heads/main"`, `"tags/v1.0.0"`, or
  either form prefixed with `"refs/"`.
  """
  @spec get_ref(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_ref(client, owner, repo, ref, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/git/ref/#{encode_ref_path(ref)}", opts)
  end

  @doc """
  Creates a Git reference pointing at a commit SHA.

  `attrs` contains `ref` and `sha`. The reference may be relative
  (`"heads/feature"` or `"tags/v1.0.0"`) or fully qualified; the request body
  always uses GitHub's required `"refs/..."` form.
  """
  @spec create_ref(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create_ref(client, owner, repo, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/git/refs",
      Keyword.put(opts, :json, qualify_ref(attrs))
    )
  end

  @doc """
  Deletes a Git reference.

  `ref` accepts the same relative or fully qualified forms as `get_ref/5`.
  GitHub refuses to delete the repository's default branch.
  """
  @spec delete_ref(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def delete_ref(client, owner, repo, ref, opts \\ []) do
    REST.delete(client, "/repos/#{owner}/#{repo}/git/refs/#{encode_ref_path(ref)}", opts)
  end

  defp qualify_ref(%{ref: ref} = attrs) when is_binary(ref),
    do: %{attrs | ref: fully_qualified_ref(ref)}

  defp qualify_ref(%{"ref" => ref} = attrs) when is_binary(ref),
    do: %{attrs | "ref" => fully_qualified_ref(ref)}

  defp qualify_ref(attrs), do: attrs

  defp fully_qualified_ref("refs/" <> _rest = ref), do: ref
  defp fully_qualified_ref(ref), do: "refs/" <> ref

  defp encode_ref_path(ref) do
    ref
    |> String.trim_leading("refs/")
    |> String.split("/")
    |> Enum.map_join("/", &URI.encode(&1, fn c -> URI.char_unreserved?(c) end))
  end
end
