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

  @doc "Searches code."
  @spec code(Client.t(), String.t(), keyword()) :: REST.result()
  def code(client, query, opts \\ []) do
    REST.get(client, "/search/code", with_query(opts, query))
  end

  @doc "Searches issues and pull requests."
  @spec issues_and_pull_requests(Client.t(), String.t(), keyword()) :: REST.result()
  def issues_and_pull_requests(client, query, opts \\ []) do
    REST.get(client, "/search/issues", with_query(opts, query))
  end

  @doc "Searches users."
  @spec users(Client.t(), String.t(), keyword()) :: REST.result()
  def users(client, query, opts \\ []) do
    REST.get(client, "/search/users", with_query(opts, query))
  end

  @doc "Searches commits."
  @spec commits(Client.t(), String.t(), keyword()) :: REST.result()
  def commits(client, query, opts \\ []) do
    REST.get(client, "/search/commits", with_query(opts, query))
  end

  defp with_query(opts, query) do
    params = Keyword.put(Keyword.get(opts, :params, []), :q, query)
    Keyword.put(opts, :params, params)
  end
end
