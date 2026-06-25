defmodule GhEx.TokenCache do
  @moduledoc """
  Behaviour for caching minted installation access tokens.

  A GitHub App installation token is valid for one hour. Rather than re-mint on
  every request, an installation client (see `GhEx.App.installation/3`) resolves its
  token through a cache implementing this behaviour. `GhEx.TokenCache.ETS` is the
  default, single-node implementation; back it with your own module to share
  tokens across a cluster (e.g. via Nebulex or Redis) without `gh_ex` depending on
  any particular cache.

  The contract is a single `c:fetch/3`: given a `key` and a `mint` function,
  return a valid (non-expired) cached value, calling `mint` and storing the result
  only on a miss or near expiry. Implementations are responsible for the freshness
  check and for ensuring `mint` runs at most once per key under concurrent callers
  (single-flight), since minting is a network round-trip.
  """

  @typedoc "A cached token and the moment it expires."
  @type value :: %{token: String.t(), expires_at: DateTime.t()}

  @typedoc "A function that mints a fresh token on a cache miss."
  @type mint :: (-> {:ok, value()} | {:error, term()})

  @doc """
  Returns a valid cached value for `key`, calling `mint` and storing its result
  when the cache has no fresh entry.
  """
  @callback fetch(ref :: term(), key :: term(), mint()) :: {:ok, value()} | {:error, term()}
end
