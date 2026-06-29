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
end
