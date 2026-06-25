defmodule GhEx.TokenCache.ETS do
  @moduledoc """
  Default `GhEx.TokenCache`: an ETS table owned by a GenServer.

  Add it to your supervision tree so it outlives individual requests:

      children = [
        GhEx.TokenCache.ETS
        # or, to run more than one or pick the name:
        # {GhEx.TokenCache.ETS, name: MyApp.GitHubTokens}
      ]

  Then point installation clients at it:

      inst = GhEx.App.installation(app, installation_id, cache: GhEx.TokenCache.ETS)

  Reads take the fast path straight from the public ETS table with no process
  hop. Misses and near-expiry refreshes are serialized through the GenServer,
  which double-checks the table before minting, so concurrent callers for the
  same installation trigger a single mint (single-flight). Serialization is
  global across keys, which is fine because mints are rare (about once per hour
  per installation); shard by running multiple named caches if you ever need to.

  A token is considered fresh until `#{60}` seconds before its `expires_at`, so a
  refresh happens slightly ahead of the real expiry.
  """

  @behaviour GhEx.TokenCache
  use GenServer

  @refresh_skew 60

  @doc "Starts the cache. `:name` defaults to `#{inspect(__MODULE__)}`."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @impl GhEx.TokenCache
  def fetch(ref, key, mint) do
    case lookup_fresh(ref, key) do
      {:ok, value} -> {:ok, value}
      :miss -> GenServer.call(ref, {:mint, key, mint})
    end
  end

  @impl GenServer
  def init(name) do
    table = :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_call({:mint, key, mint}, _from, state) do
    # Re-check under serialization: another caller may have minted while we queued.
    case lookup_fresh(state.table, key) do
      {:ok, value} ->
        {:reply, {:ok, value}, state}

      :miss ->
        case mint.() do
          {:ok, value} ->
            :ets.insert(state.table, {key, value})
            {:reply, {:ok, value}, state}

          {:error, _reason} = error ->
            {:reply, error, state}
        end
    end
  end

  defp lookup_fresh(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> if fresh?(value), do: {:ok, value}, else: :miss
      [] -> :miss
    end
  end

  defp fresh?(%{expires_at: %DateTime{} = expires_at}) do
    DateTime.diff(expires_at, DateTime.utc_now()) > @refresh_skew
  end

  defp fresh?(_value), do: false
end
