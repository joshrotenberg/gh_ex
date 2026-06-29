defmodule GhEx.RateLimit do
  @moduledoc """
  Rate-limit headers and an opt-in retry for GitHub's rate limits.

  `from_response/1` parses the `x-ratelimit-*` headers into a snapshot.

  `retry/2` is a `Req`-compatible retry policy. `Req` already retries ordinary
  transient errors (5xx, network errors) on its own; this adds awareness of
  GitHub's secondary rate limits, which arrive as a `403` (not retried by
  default) carrying a `retry-after` header or `x-ratelimit-remaining: 0`. Enable
  it through `:req_options`:

      GhEx.new(
        auth: {:token, token},
        req_options: [retry: &GhEx.RateLimit.retry/2]
      )

  `Req` bounds the attempts with `:max_retries` (default 3).
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

  # GitHub recommends waiting at least 60s before retrying a secondary rate
  # limit that arrives without a `retry-after` header.
  @secondary_delay_ms 60_000

  @doc """
  A `Req`-compatible retry policy that understands GitHub's rate limits.

  Returns `{:delay, ms}` for a `403` or `429` that signals a rate limit, waiting
  the `retry-after` header or, when `x-ratelimit-remaining` is `0`, until
  `x-ratelimit-reset`. GitHub's secondary rate limit can arrive as a `403` whose
  only signal is the body message "You have exceeded a secondary rate limit"; in
  that case (no `retry-after`, `x-ratelimit-remaining` not `0`) the body is
  inspected and a bounded `{:delay, #{@secondary_delay_ms}}` is returned, the
  minimum GitHub recommends. Other `429`s and the usual transient statuses
  (`408`, `500`, `502`, `503`, `504`) return `true` so `Req` applies its own
  backoff. A plain `403` (an authorization failure, not a rate limit) is not
  retried. Wire it in through `:req_options`; `Req` applies `:max_retries`.
  """
  @spec retry(Req.Request.t(), Req.Response.t() | Exception.t()) ::
          {:delay, non_neg_integer()} | boolean()
  def retry(_request, %Req.Response{status: status} = resp) when status in [403, 429] do
    case rate_limit_delay_ms(resp) do
      nil -> status == 429
      ms -> {:delay, ms}
    end
  end

  def retry(_request, %Req.Response{status: status}) when status in [408, 500, 502, 503, 504] do
    true
  end

  def retry(_request, _response_or_exception), do: false

  defp rate_limit_delay_ms(resp) do
    cond do
      (after_s = header_int(resp, "retry-after")) != nil ->
        max(0, after_s) * 1000

      header_int(resp, "x-ratelimit-remaining") == 0 ->
        case header_int(resp, "x-ratelimit-reset") do
          nil -> nil
          reset -> max(0, reset - System.system_time(:second)) * 1000
        end

      secondary_rate_limit?(resp) ->
        @secondary_delay_ms

      true ->
        nil
    end
  end

  defp secondary_rate_limit?(%Req.Response{body: %{"message" => message}})
       when is_binary(message) do
    String.contains?(String.downcase(message), "secondary rate limit")
  end

  defp secondary_rate_limit?(_resp), do: false

  @doc """
  Fetches rate-limit status from `GET /rate_limit`.

  This endpoint does not count against your rate limit. Returns the full body,
  whose `"resources"` map covers `core`, `search`, `graphql`, and others.
  """
  @spec get(GhEx.Client.t()) :: GhEx.REST.result()
  def get(client), do: GhEx.REST.get(client, "/rate_limit")

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
