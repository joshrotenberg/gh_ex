defmodule GhEx.Activity do
  @moduledoc """
  Convenience functions for GitHub activity events and repository starring.

  Event feeds are delayed activity streams rather than real-time delivery; use
  webhooks when latency matters. Every list has a lazy `stream_*` companion.
  Watching/subscription endpoints are intentionally outside this module's
  scope; notification-thread subscriptions live in `GhEx.Notifications`.

  Except for the documented boolean body returned by `starred?/4`, these thin
  wrappers return the same `{:ok, body, meta}` / `{:error, reason}` shape as
  `GhEx.REST` and pass `opts` through to `Req`.
  """

  alias GhEx.{Client, REST}

  @doc "Lists events for a repository."
  @spec list_repo_events(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_repo_events(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/events", opts)
  end

  @doc "Auto-paginates repository events into a lazy `Stream`."
  @spec stream_repo_events(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_repo_events(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/events", opts)
  end

  @doc "Lists public events for an organization."
  @spec list_org_events(Client.t(), String.t(), keyword()) :: REST.result()
  def list_org_events(client, org, opts \\ []) do
    REST.get(client, "/orgs/#{org}/events", opts)
  end

  @doc "Auto-paginates an organization's public events into a lazy `Stream`."
  @spec stream_org_events(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_org_events(client, org, opts \\ []) do
    REST.stream(client, "/orgs/#{org}/events", opts)
  end

  @doc """
  Lists events performed by a user.

  When authenticated as `username`, the response may include private events;
  otherwise GitHub returns only public events.
  """
  @spec list_user_events(Client.t(), String.t(), keyword()) :: REST.result()
  def list_user_events(client, username, opts \\ []) do
    REST.get(client, "/users/#{username}/events", opts)
  end

  @doc "Auto-paginates events performed by a user into a lazy `Stream`."
  @spec stream_user_events(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_user_events(client, username, opts \\ []) do
    REST.stream(client, "/users/#{username}/events", opts)
  end

  @doc "Lists public events across GitHub."
  @spec list_public_events(Client.t(), keyword()) :: REST.result()
  def list_public_events(client, opts \\ []) do
    REST.get(client, "/events", opts)
  end

  @doc "Auto-paginates public events across GitHub into a lazy `Stream`."
  @spec stream_public_events(Client.t(), keyword()) :: Enumerable.t()
  def stream_public_events(client, opts \\ []) do
    REST.stream(client, "/events", opts)
  end

  @doc """
  Lists a repository's stargazers.

  Pass an `application/vnd.github.star+json` Accept header to include each
  star's timestamp. GitHub may restrict this listing to repository admins and
  collaborators.
  """
  @spec list_stargazers(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_stargazers(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/stargazers", opts)
  end

  @doc "Auto-paginates a repository's stargazers into a lazy `Stream`."
  @spec stream_stargazers(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_stargazers(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/stargazers", opts)
  end

  @doc "Lists repositories starred by a user."
  @spec list_starred(Client.t(), String.t(), keyword()) :: REST.result()
  def list_starred(client, username, opts \\ []) do
    REST.get(client, "/users/#{username}/starred", opts)
  end

  @doc "Auto-paginates repositories starred by a user into a lazy `Stream`."
  @spec stream_starred(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_starred(client, username, opts \\ []) do
    REST.stream(client, "/users/#{username}/starred", opts)
  end

  @doc """
  Checks whether the authenticated user has starred a repository.

  Returns `{:ok, true, meta}` for GitHub's `204` response and
  `{:ok, false, meta}` for its `404` absence response. Other failures remain
  `{:error, %GhEx.Error{}}`. A conditional `304` is returned as
  `{:ok, :not_modified, meta}`, consistent with `GhEx.REST`.
  """
  @spec starred?(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def starred?(client, owner, repo, opts \\ []) do
    REST.present?(client, "/user/starred/#{owner}/#{repo}", opts)
  end

  @doc "Stars a repository for the authenticated user."
  @spec star(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def star(client, owner, repo, opts \\ []) do
    REST.put(client, "/user/starred/#{owner}/#{repo}", opts)
  end

  @doc "Unstars a repository for the authenticated user."
  @spec unstar(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def unstar(client, owner, repo, opts \\ []) do
    REST.delete(client, "/user/starred/#{owner}/#{repo}", opts)
  end
end
