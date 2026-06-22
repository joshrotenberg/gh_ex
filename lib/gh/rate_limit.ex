defmodule GH.RateLimit do
  @moduledoc """
  A snapshot of the rate-limit headers GitHub sends on every REST response.

  M1 parses the headers into a struct so callers can see where they stand.
  Automatic secondary-limit backoff is an M4 concern.
  """

  @type t :: %__MODULE__{
          limit: non_neg_integer() | nil,
          remaining: non_neg_integer() | nil,
          used: non_neg_integer() | nil,
          reset: DateTime.t() | nil,
          resource: String.t() | nil
        }

  defstruct limit: nil, remaining: nil, used: nil, reset: nil, resource: nil

  @doc """
  Builds a snapshot from a response, or `nil` when no rate-limit headers exist.
  """
  @spec from_response(Req.Response.t()) :: t() | nil
  def from_response(%Req.Response{} = resp) do
    limit = header_int(resp, "x-ratelimit-limit")
    remaining = header_int(resp, "x-ratelimit-remaining")

    if is_nil(limit) and is_nil(remaining) do
      nil
    else
      %__MODULE__{
        limit: limit,
        remaining: remaining,
        used: header_int(resp, "x-ratelimit-used"),
        reset: header_reset(resp),
        resource: header_str(resp, "x-ratelimit-resource")
      }
    end
  end

  defp header_str(resp, name) do
    case Req.Response.get_header(resp, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp header_int(resp, name) do
    with value when is_binary(value) <- header_str(resp, name),
         {int, _} <- Integer.parse(value) do
      int
    else
      _ -> nil
    end
  end

  defp header_reset(resp) do
    case header_int(resp, "x-ratelimit-reset") do
      nil -> nil
      epoch -> DateTime.from_unix!(epoch)
    end
  end
end
