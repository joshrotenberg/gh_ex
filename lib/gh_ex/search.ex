defmodule GhEx.Search do
  @moduledoc """
  Convenience functions for the GitHub Search REST API.

  Each function takes the search `query` (the `q` parameter) and returns the same
  `{:ok, body, meta}` / `{:error, reason}` shape as `GhEx.REST`. Pass
  `params: [sort: ..., order: ..., per_page: ...]` for the other search options;
  `q` is merged in.
  """

  alias GhEx.{Client, REST}

  @doc "Searches repositories."
  @spec repositories(Client.t(), String.t(), keyword()) :: REST.result()
  def repositories(client, query, opts \\ []) do
    REST.get(client, "/search/repositories", with_query(opts, query))
  end

  @doc """
  Auto-paginates a repository search into a lazy `Stream` of individual results,
  unwrapping the `"items"` array on each page (see `GhEx.REST.stream/3`).
  """
  @spec stream_repositories(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_repositories(client, query, opts \\ []) do
    REST.stream(client, "/search/repositories", with_items(opts, query))
  end

  @doc "Searches code."
  @spec code(Client.t(), String.t(), keyword()) :: REST.result()
  def code(client, query, opts \\ []) do
    REST.get(client, "/search/code", with_query(opts, query))
  end

  @doc "Auto-paginates a code search into a lazy `Stream`, unwrapping `\"items\"`."
  @spec stream_code(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_code(client, query, opts \\ []) do
    REST.stream(client, "/search/code", with_items(opts, query))
  end

  @doc "Searches issues and pull requests."
  @spec issues_and_pull_requests(Client.t(), String.t(), keyword()) :: REST.result()
  def issues_and_pull_requests(client, query, opts \\ []) do
    REST.get(client, "/search/issues", with_query(opts, query))
  end

  @doc "Auto-paginates an issue and pull request search into a lazy `Stream`, unwrapping `\"items\"`."
  @spec stream_issues_and_pull_requests(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_issues_and_pull_requests(client, query, opts \\ []) do
    REST.stream(client, "/search/issues", with_items(opts, query))
  end

  @doc "Searches users."
  @spec users(Client.t(), String.t(), keyword()) :: REST.result()
  def users(client, query, opts \\ []) do
    REST.get(client, "/search/users", with_query(opts, query))
  end

  @doc "Auto-paginates a user search into a lazy `Stream`, unwrapping `\"items\"`."
  @spec stream_users(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_users(client, query, opts \\ []) do
    REST.stream(client, "/search/users", with_items(opts, query))
  end

  @doc "Searches commits."
  @spec commits(Client.t(), String.t(), keyword()) :: REST.result()
  def commits(client, query, opts \\ []) do
    REST.get(client, "/search/commits", with_query(opts, query))
  end

  @doc "Auto-paginates a commit search into a lazy `Stream`, unwrapping `\"items\"`."
  @spec stream_commits(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_commits(client, query, opts \\ []) do
    REST.stream(client, "/search/commits", with_items(opts, query))
  end

  defp with_query(opts, query) do
    params =
      opts
      |> Keyword.get(:params, [])
      |> Enum.to_list()
      |> Keyword.put(:q, query)

    Keyword.put(opts, :params, params)
  end

  defp with_items(opts, query) do
    opts
    |> with_query(query)
    |> Keyword.put(:items, "items")
  end
end
