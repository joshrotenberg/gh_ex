defmodule GhEx.Stacks do
  @moduledoc """
  Convenience functions for GitHub's Stacks REST API.

  A stack is addressed by its repository-scoped stack number. Pull request
  numbers passed to `create/5` and `add/6` must be ordered from the bottom of
  the stack to the top.

  Stacked pull requests are in public preview. GitHub returns `404 Not Found`
  when the feature is not yet available for a repository.

  Each function is a thin wrapper over `GhEx.REST` and returns the same
  `{:ok, body, meta}` / `{:error, reason}` shape.
  """

  alias GhEx.{Client, REST}

  @type number_ref :: integer() | String.t()

  @doc """
  Lists stacks in a repository. Use `params: [pull_request: number]` to find the
  stack containing a particular pull request.
  """
  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/stacks", opts)
  end

  @doc "Auto-paginates repository stacks into a lazy `Stream`."
  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/stacks", opts)
  end

  @doc "Gets a stack by its repository-scoped stack number."
  @spec get(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def get(client, owner, repo, stack_number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/stacks/#{stack_number}", opts)
  end

  @doc """
  Creates a stack. `attrs` must contain `pull_requests`, an ordered list of pull
  request numbers from bottom to top (minimum 2, maximum 100).
  """
  @spec create(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/stacks", Keyword.put(opts, :json, attrs))
  end

  @doc """
  Adds pull requests to the top of a stack. `attrs` must contain
  `pull_requests`, ordered from the stack's current top upward.
  """
  @spec add(Client.t(), String.t(), String.t(), number_ref(), map(), keyword()) :: REST.result()
  def add(client, owner, repo, stack_number, attrs, opts \\ []) do
    REST.post(
      client,
      "/repos/#{owner}/#{repo}/stacks/#{stack_number}/add",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc """
  Removes the unmerged pull requests from a stack.

  Pull requests that are merged, merging, or queued for merge remain. GitHub
  returns the remaining stack with `200`, or `204 No Content` when the stack is
  fully dissolved.
  """
  @spec unstack(Client.t(), String.t(), String.t(), number_ref(), keyword()) :: REST.result()
  def unstack(client, owner, repo, stack_number, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/stacks/#{stack_number}/unstack", opts)
  end
end
