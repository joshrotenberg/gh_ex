defmodule GhEx.Hooks do
  @moduledoc """
  Repository webhook configuration management.

  This module manages hooks through GitHub's REST API. `GhEx.Webhooks` remains
  the receiving side for verifying signatures and parsing delivery payloads.

  The wrappers return the same `{:ok, body, meta}` / `{:error, reason}` shape as
  `GhEx.REST`; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @type id :: integer() | String.t()

  @doc "Lists repository webhooks."
  @spec list(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/hooks", opts)
  end

  @doc "Auto-paginates repository webhooks into a lazy `Stream`."
  @spec stream(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/hooks", opts)
  end

  @doc "Gets a repository webhook by id."
  @spec get(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def get(client, owner, repo, hook_id, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/hooks/#{hook_id}", opts)
  end

  @doc "Creates a repository webhook. `attrs` contains its config, events, and active state."
  @spec create(Client.t(), String.t(), String.t(), map(), keyword()) :: REST.result()
  def create(client, owner, repo, attrs, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/hooks", Keyword.put(opts, :json, attrs))
  end

  @doc """
  Updates a repository webhook.

  When a hook already has a secret, include that secret again or replace it.
  GitHub removes an existing secret when the update omits it.
  """
  @spec update(Client.t(), String.t(), String.t(), id(), map(), keyword()) :: REST.result()
  def update(client, owner, repo, hook_id, attrs, opts \\ []) do
    REST.patch(
      client,
      "/repos/#{owner}/#{repo}/hooks/#{hook_id}",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Deletes a repository webhook. GitHub returns `204 No Content` on success."
  @spec delete(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def delete(client, owner, repo, hook_id, opts \\ []) do
    REST.delete(client, "/repos/#{owner}/#{repo}/hooks/#{hook_id}", opts)
  end

  @doc "Sends a `ping` event to a repository webhook."
  @spec ping(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def ping(client, owner, repo, hook_id, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/hooks/#{hook_id}/pings", opts)
  end

  @doc """
  Sends the repository's latest push to a hook subscribed to `push` events.

  GitHub returns `204` without a delivery when the hook does not subscribe to
  `push` events.
  """
  @spec test(Client.t(), String.t(), String.t(), id(), keyword()) :: REST.result()
  def test(client, owner, repo, hook_id, opts \\ []) do
    REST.post(client, "/repos/#{owner}/#{repo}/hooks/#{hook_id}/tests", opts)
  end
end
