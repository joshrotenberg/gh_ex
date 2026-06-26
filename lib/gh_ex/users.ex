defmodule GhEx.Users do
  @moduledoc """
  Convenience functions for the GitHub Users REST API.

  Thin wrappers over `GhEx.REST` that return the same `{:ok, body, meta}` /
  `{:error, reason}` shape; `opts` pass through to `Req`.
  """

  alias GhEx.{Client, REST}

  @doc "Gets a user by username."
  @spec get(Client.t(), String.t(), keyword()) :: REST.result()
  def get(client, username, opts \\ []) do
    REST.get(client, "/users/#{username}", opts)
  end

  @doc "Gets the authenticated user."
  @spec get_authenticated(Client.t(), keyword()) :: REST.result()
  def get_authenticated(client, opts \\ []) do
    REST.get(client, "/user", opts)
  end

  @doc "Lists followers of a user."
  @spec list_followers(Client.t(), String.t(), keyword()) :: REST.result()
  def list_followers(client, username, opts \\ []) do
    REST.get(client, "/users/#{username}/followers", opts)
  end

  @doc "Lists users followed by a user."
  @spec list_following(Client.t(), String.t(), keyword()) :: REST.result()
  def list_following(client, username, opts \\ []) do
    REST.get(client, "/users/#{username}/following", opts)
  end

  @doc "Lists email addresses for the authenticated user."
  @spec list_emails(Client.t(), keyword()) :: REST.result()
  def list_emails(client, opts \\ []) do
    REST.get(client, "/user/emails", opts)
  end
end
