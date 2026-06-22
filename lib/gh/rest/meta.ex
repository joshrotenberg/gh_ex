defmodule GH.REST.Meta do
  @moduledoc """
  Metadata accompanying a successful REST response.

    * `:status` - the HTTP status code.
    * `:headers` - the raw response headers, as returned by `Req`.
    * `:links` - parsed pagination links, e.g. `%{"next" => url, "last" => url}`.
      Empty when the endpoint is not paginated.
    * `:rate_limit` - a `GH.RateLimit` snapshot, or `nil` if the headers were absent.
  """

  @type t :: %__MODULE__{
          status: pos_integer(),
          headers: map() | list(),
          links: %{optional(String.t()) => String.t()},
          rate_limit: GH.RateLimit.t() | nil
        }

  defstruct status: nil, headers: %{}, links: %{}, rate_limit: nil
end
