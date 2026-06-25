defmodule GhEx.GraphQL.Meta do
  @moduledoc """
  Metadata accompanying a successful GraphQL response.

    * `:status` - the HTTP status code (200 for both success and GraphQL errors).
    * `:headers` - the raw response headers, as returned by `Req`.
    * `:rate_limit` - a `GhEx.RateLimit` snapshot parsed from the `x-ratelimit-*`
      response headers, or `nil` if absent.
    * `:cost` - the GraphQL rate-limit cost block (`%{"cost" => _, "remaining" => _,
      "resetAt" => _, ...}`) when the query selected a `rateLimit { ... }` field,
      otherwise `nil`. Kept as the raw map so no fields are lost; `:rate_limit`
      remains the header-based view for parity with `GhEx.REST.Meta`.
  """

  @type t :: %__MODULE__{
          status: pos_integer() | nil,
          headers: map() | list(),
          rate_limit: GhEx.RateLimit.t() | nil,
          cost: map() | nil
        }

  defstruct status: nil, headers: %{}, rate_limit: nil, cost: nil
end
