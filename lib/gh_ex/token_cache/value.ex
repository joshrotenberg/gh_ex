defmodule GhEx.TokenCache.Value do
  @moduledoc """
  An opaque, redacting cached installation access token and its expiry.

  This is the value `GhEx` mints on a cache miss and the value a
  `GhEx.TokenCache` implementation stores and returns. The `:token` is a secret,
  so it is excluded from `Inspect`: it never appears in `inspect/1`, IEx echoes,
  or an ETS-cache crash dump. The struct still matches `%{token: _, expires_at: _}`,
  so a cache implementation and the freshness check can treat it as a plain map.

  A custom cache never constructs a `Value`; it receives one from the
  `GhEx`-supplied `mint` and handles it opaquely. Keeping the public
  `t:GhEx.TokenCache.value/0` type tied to this struct (rather than a bare map)
  preserves the redacting shape on the mint path.
  """

  @derive {Inspect, except: [:token]}
  defstruct [:token, :expires_at]

  @type t :: %__MODULE__{token: String.t(), expires_at: DateTime.t()}
end
