defmodule GhEx.Commits do
  @moduledoc """
  Convenience functions for GitHub's commit-detail REST APIs.

  This module covers single commits, comparisons, associated pull requests, and
  commit comments. Repository-wide commit listing remains available through
  `GhEx.Repositories.list_commits/4` and `GhEx.Repositories.stream_commits/4`.

  These thin wrappers return the same `{:ok, body, meta}` / `{:error, reason}`
  shape as `GhEx.REST` and pass `opts` through to `Req`.
  """

  alias GhEx.{Client, REST}

  @type ref :: String.t()

  @doc "Gets a commit by SHA, branch name, or tag name."
  @spec get(Client.t(), String.t(), String.t(), ref(), keyword()) :: REST.result()
  def get(client, owner, repo, ref, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits/#{encode_segment(ref)}", opts)
  end

  @doc """
  Compares `base` to `head`.

  Each side may be a SHA, branch, tag, or a cross-fork form such as
  `"octocat:feature"`. Use `params:` for `page` and `per_page`.
  """
  @spec compare(Client.t(), String.t(), String.t(), ref(), ref(), keyword()) :: REST.result()
  def compare(client, owner, repo, base, head, opts \\ []) do
    REST.get(
      client,
      "/repos/#{owner}/#{repo}/compare/#{encode_segment(base)}...#{encode_segment(head)}",
      opts
    )
  end

  @doc "Lists pull requests associated with a commit SHA."
  @spec list_pulls(Client.t(), String.t(), String.t(), ref(), keyword()) :: REST.result()
  def list_pulls(client, owner, repo, sha, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits/#{encode_segment(sha)}/pulls", opts)
  end

  @doc "Auto-paginates pull requests associated with a commit into a lazy `Stream`."
  @spec stream_pulls(Client.t(), String.t(), String.t(), ref(), keyword()) :: Enumerable.t()
  def stream_pulls(client, owner, repo, sha, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/commits/#{encode_segment(sha)}/pulls", opts)
  end

  @doc "Lists comments on a commit."
  @spec list_comments(Client.t(), String.t(), String.t(), ref(), keyword()) :: REST.result()
  def list_comments(client, owner, repo, ref, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/commits/#{encode_segment(ref)}/comments", opts)
  end

  @doc "Auto-paginates comments on a commit into a lazy `Stream`."
  @spec stream_comments(Client.t(), String.t(), String.t(), ref(), keyword()) :: Enumerable.t()
  def stream_comments(client, owner, repo, ref, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/commits/#{encode_segment(ref)}/comments", opts)
  end

  @doc """
  Creates a comment on a commit.

  `attrs` requires `body`. To anchor it to a diff, also provide `path` and
  `position`; GitHub is closing down the older `line` parameter.
  """
  @spec create_comment(Client.t(), String.t(), String.t(), ref(), map(), keyword()) ::
          REST.result()
  def create_comment(client, owner, repo, sha, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/commits/#{encode_segment(sha)}/comments",
      Keyword.put(opts, :json, attrs)
    )
  end

  defp encode_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
