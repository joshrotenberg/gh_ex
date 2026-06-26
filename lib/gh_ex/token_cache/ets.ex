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
  hop. Misses and near-expiry refreshes go through the GenServer, which
  double-checks the table and then runs the mint in a monitored worker process,
  replying to every caller that joined while it ran. Concurrent callers for the
  same installation therefore trigger a single mint (single-flight), while mints
  for different installations run concurrently and never head-of-line-block each
  other. The GenServer itself never blocks on the network: a slow mint holds up
  only the callers waiting on that key, not the table or other keys.

  Because the mint runs off the GenServer, `fetch/3` waits on it with an
  `:infinity` `GenServer.call` timeout: the mint's own deadline (the client's
  `Req` `receive_timeout`, 15s by default, plus any opted-in
  `GhEx.RateLimit.retry/2` `retry-after` sleep) is the only deadline, exactly as
  for a direct request through the same client. The previous default 5s
  `GenServer.call` deadline could fire mid-mint and surface a raw
  `exit({:timeout, ...})` instead of `{:ok, body, meta} | {:error, reason}`.

  A token is considered fresh until `#{60}` seconds before its `expires_at`, so a
  refresh happens slightly ahead of the real expiry.
  """

  @behaviour GhEx.TokenCache
  use GenServer

  @refresh_skew 60

  @doc """
  Builds a supervisor child spec whose `:id` is the `:name`, so several named
  caches can run under one supervisor without an id clash.
  """
  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    %{
      id: name,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @doc "Starts the cache. `:name` defaults to `#{inspect(__MODULE__)}`."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @impl GhEx.TokenCache
  def fetch(ref, key, mint) do
    case lookup_fresh(ref, key) do
      # :infinity defers to the mint's own deadline; see the moduledoc.
      {:ok, value} -> {:ok, value}
      :miss -> GenServer.call(ref, {:mint, key, mint}, :infinity)
    end
  end

  @impl GenServer
  def init(name) do
    table = :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: table, inflight: %{}, keys: %{}}}
  end

  @impl GenServer
  def handle_call({:mint, key, mint}, from, state) do
    # Re-check under serialization: another caller may have minted while we queued.
    case lookup_fresh(state.table, key) do
      {:ok, value} -> {:reply, {:ok, value}, state}
      :miss -> {:noreply, claim(state, key, mint, from)}
    end
  end

  # Join an in-flight mint for this key, or start one if none is running. Either
  # way `from` is parked and answered later via GenServer.reply, so the GenServer
  # stays responsive while the network round-trip happens off-process.
  defp claim(state, key, mint, from) do
    case state.inflight do
      %{^key => waiters} ->
        %{state | inflight: Map.put(state.inflight, key, [from | waiters])}

      _ ->
        ref = start_mint(key, mint)

        %{
          state
          | inflight: Map.put(state.inflight, key, [from]),
            keys: Map.put(state.keys, ref, key)
        }
    end
  end

  defp start_mint(key, mint) do
    server = self()
    # Carry $callers into the worker the way Task does, so caller-based process
    # ownership (e.g. Req.Test / NimbleOwnership allowances granted to this
    # GenServer) still resolves for the mint's network call.
    callers = [server | Process.get(:"$callers", [])]

    {_pid, ref} =
      spawn_monitor(fn ->
        Process.put(:"$callers", callers)

        result =
          try do
            mint.()
          rescue
            exception -> {:error, exception}
          catch
            kind, reason -> {:error, {kind, reason}}
          end

        send(server, {:mint_result, key, result})
      end)

    ref
  end

  @impl GenServer
  def handle_info({:mint_result, key, {:ok, value} = result}, state) do
    :ets.insert(state.table, {key, value})
    {:noreply, reply_waiters(state, key, result)}
  end

  def handle_info({:mint_result, key, {:error, _reason} = result}, state) do
    {:noreply, reply_waiters(state, key, result)}
  end

  # The worker catches its own exceptions and always sends a :mint_result before
  # exiting, so a :normal DOWN is just cleanup. A non-normal exit (e.g. a brutal
  # kill) means no result was sent, so fail the parked waiters rather than hang
  # them on the :infinity call.
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.keys, ref) do
      {nil, _keys} ->
        {:noreply, state}

      {key, keys} ->
        state = %{state | keys: keys}

        if reason != :normal and Map.has_key?(state.inflight, key) do
          {:noreply, reply_waiters(state, key, {:error, {:mint_crashed, reason}})}
        else
          {:noreply, state}
        end
    end
  end

  defp reply_waiters(state, key, result) do
    case Map.pop(state.inflight, key) do
      {nil, _inflight} ->
        state

      {waiters, inflight} ->
        Enum.each(waiters, &GenServer.reply(&1, result))
        %{state | inflight: inflight}
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
