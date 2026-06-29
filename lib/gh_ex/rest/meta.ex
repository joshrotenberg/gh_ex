defmodule GhEx.REST.Meta do
  @moduledoc """
  Metadata accompanying a successful REST response.

    * `:status` - the HTTP status code.
    * `:headers` - the raw response headers, as returned by `Req`.
    * `:links` - parsed pagination links, e.g. `%{"next" => url, "last" => url}`.
      Empty when the endpoint is not paginated.
    * `:rate_limit` - a `GhEx.RateLimit` snapshot, or `nil` if the headers were absent.
    * `:etag` - the `ETag` header value, or `nil` when absent. Store it and send it
      back as `If-None-Match` on a later request to get a `304` (see `GhEx.REST`).
    * `:last_modified` - the `Last-Modified` header value, or `nil` when absent.
      Usable as `If-Modified-Since` for the same effect.
  """

  @type t :: %__MODULE__{
          status: pos_integer() | nil,
          headers: map() | list(),
          links: %{optional(String.t()) => String.t()},
          rate_limit: GhEx.RateLimit.t() | nil,
          etag: String.t() | nil,
          last_modified: String.t() | nil
        }

  defstruct status: nil, headers: %{}, links: %{}, rate_limit: nil, etag: nil, last_modified: nil
end
