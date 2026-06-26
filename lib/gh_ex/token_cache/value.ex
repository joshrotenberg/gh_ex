defmodule GhEx.TokenCache.Value do
  @moduledoc false
  # A cached installation access token and its expiry. The token is a secret, so
  # `:token` is excluded from Inspect: it never appears in `inspect/1`, IEx echoes,
  # or an ETS-cache crash dump. The struct still matches `%{token: _, expires_at: _}`,
  # so cache implementations and the freshness check treat it as a plain map.

  @derive {Inspect, except: [:token]}
  defstruct [:token, :expires_at]

  @type t :: %__MODULE__{token: String.t(), expires_at: DateTime.t()}
end
