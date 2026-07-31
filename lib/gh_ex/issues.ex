defmodule GhEx.Issues do
  @moduledoc """
  Convenience functions for the GitHub Issues REST API.

  Each function is a thin wrapper over `GhEx.REST` that fills in the endpoint
  path. They return the same `{:ok, body, meta}` / `{:error, reason}` shape as
  `GhEx.REST` and pass `opts` through to `Req`, so `:params`, headers, and a
  `Req.Test` plug all work. For an endpoint without a wrapper, call `GhEx.REST`
  directly.
  """

  alias GhEx.{Client, REST}

  @type number_ref :: integer() | String.t()

  @doc """
  Lists issues in a repository. Use `params:` for `state`, `labels`, `per_page`,
  and the other query options.
  """
  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/issues", opts)
  end

  @doc """
  Auto-paginates issues in a repository into a lazy `Stream` of individual
  issues, following `Link: rel="next"` (see `GhEx.REST.stream/3`).
  """
  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/issues", opts)
  end

  @doc "Gets a single issue by number."
  @spec get(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def get(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/issues/#{number}", opts)
  end

  @doc "Creates an issue. `attrs` is the JSON body (title, body, labels, assignees, ...)."
  @spec create(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/issues", Keyword.put(opts, :json, attrs))
  end

  @doc "Updates an issue. `attrs` may set title, body, state, labels, and so on."
  @spec update(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) ::
          REST.result()
  def update(client, owner, repo, number, attrs, opts \\ []) do
    REST.patch(
      client,
      "/repos/#{owner}/#{repo}/issues/#{number}",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Lists the comments on an issue."
  @spec list_comments(Client.t(), String.t(), String.t(), number_ref(), keyword()) ::
          REST.result()
  def list_comments(client, owner, repo, number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/issues/#{number}/comments", opts)
  end

  @doc "Auto-paginates the comments on an issue into a lazy `Stream`."
  @spec stream_comments(Client.t(), String.t(), String.t(), number_ref(), keyword()) ::
          Enumerable.t()
  def stream_comments(client, owner, repo, number, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/issues/#{number}/comments", opts)
  end

  @doc "Adds a comment to an issue."
  @spec create_comment(Client.t(), String.t(), String.t(), number_ref(), String.t(), keyword()) ::
          REST.result()
  def create_comment(client, owner, repo, number, body, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/issues/#{number}/comments",
      Keyword.put(opts, :json, %{body: body})
    )
  end

  @doc """
  Updates an issue or pull request comment.

  Useful for rolling status comments that should be edited in place instead of
  creating a new comment on every update.
  """
  @spec update_comment(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          String.t(),
          keyword()
        ) :: REST.result()
  def update_comment(client, owner, repo, comment_id, body, opts \\ []) do
    REST.patch(
      client,
      "/repos/#{owner}/#{repo}/issues/comments/#{comment_id}",
      Keyword.put(opts, :json, %{body: body})
    )
  end

  @doc """
  Adds up to 10 assignees without replacing the issue's existing assignees.

  GitHub silently ignores users who cannot be assigned.
  """
  @spec add_assignees(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          [String.t()],
          keyword()
        ) :: REST.result()
  def add_assignees(client, owner, repo, number, assignees, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/issues/#{number}/assignees",
      Keyword.put(opts, :json, %{assignees: assignees})
    )
  end

  @doc "Removes selected assignees without changing any other assignees."
  @spec remove_assignees(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          [String.t()],
          keyword()
        ) :: REST.result()
  def remove_assignees(client, owner, repo, number, assignees, opts \\ []) do
    REST.delete(
      client,
      "/repos/#{owner}/#{repo}/issues/#{number}/assignees",
      Keyword.put(opts, :json, %{assignees: assignees})
    )
  end

  @doc "Lists the labels defined for a repository."
  @spec list_labels(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_labels(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/labels", opts)
  end

  @doc "Auto-paginates the labels defined for a repository into a lazy `Stream`."
  @spec stream_labels(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_labels(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/labels", opts)
  end

  @doc """
  Gets a repository label by name.

  The name is percent-encoded as one path segment, so spaces, slashes, and
  other reserved characters are safe to pass directly.
  """
  @spec get_label(Client.t(), String.t(), String.t(), String.t(), keyword()) :: REST.result()
  def get_label(client, owner, repo, name, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/labels/#{encode_segment(name)}", opts)
  end

  @doc """
  Creates a repository label. `attrs` requires `name` and `color` and may set
  `description`.

  Creating an existing name returns GitHub's `422` `already_exists` validation
  error as a `GhEx.Error`. An additive reconciler can catch that error, update
  the existing label, and re-fetch the repository labels between passes to
  account for concurrent writers.
  """
  @spec create_label(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create_label(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/labels", Keyword.put(opts, :json, attrs))
  end

  @doc """
  Updates a repository label identified by its current name.

  `attrs` may set `new_name`, `color`, and `description`. The current name is
  percent-encoded as one path segment.
  """
  @spec update_label(
          Client.t(),
          String.t(),
          String.t(),
          String.t(),
          map(),
          keyword()
        ) :: REST.result()
  def update_label(client, owner, repo, name, attrs, opts \\ []) do
    REST.patch(
      client,
      "/repos/#{owner}/#{repo}/labels/#{encode_segment(name)}",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Adds labels to an issue. `labels` is a list of label names."
  @spec add_labels(Client.t(), String.t(), String.t(), number_ref(), [String.t()], keyword()) ::
          REST.result()
  def add_labels(client, owner, repo, number, labels, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/issues/#{number}/labels",
      Keyword.put(opts, :json, %{labels: labels})
    )
  end

  @doc """
  Removes one label from an issue.

  Label names are percent-encoded as a single path segment, so names containing
  spaces, slashes, or other reserved characters are safe to pass directly.
  """
  @spec remove_label(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          String.t(),
          keyword()
        ) :: REST.result()
  def remove_label(client, owner, repo, number, name, opts \\ []) do
    REST.delete(
      client,
      "/repos/#{owner}/#{repo}/issues/#{number}/labels/#{encode_segment(name)}",
      opts
    )
  end

  @doc "Replaces every label on an issue. Pass an empty list to remove all labels."
  @spec replace_all_labels(
          Client.t(),
          String.t(),
          String.t(),
          number_ref(),
          [String.t()],
          keyword()
        ) :: REST.result()
  def replace_all_labels(client, owner, repo, number, labels, opts \\ []) do
    REST.put(
      client,
      "/repos/#{owner}/#{repo}/issues/#{number}/labels",
      Keyword.put(opts, :json, %{labels: labels})
    )
  end

  defp encode_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
