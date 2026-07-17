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
  def from_response(%Req.Response{headers: headers}) do
    limit = header_int(headers, "x-ratelimit-limit")
    remaining = header_int(headers, "x-ratelimit-remaining")

    if is_nil(limit) and is_nil(remaining) do
      nil
    else
      %__MODULE__{
        limit: limit,
        remaining: remaining,
        used: header_int(headers, "x-ratelimit-used"),
        reset: header_reset(headers),
        resource: header_str(headers, "x-ratelimit-resource")
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
    case rate_limit_delay_ms(resp.headers, resp.body) do
      nil -> status == 429
      ms -> {:delay, ms}
    end
  end

  def retry(_request, %Req.Response{status: status}) when status in [408, 500, 502, 503, 504] do
    true
  end

  def retry(_request, _response_or_exception), do: false

  @doc """
  True when `status`, `headers`, and `body` together signal one of GitHub's
  rate limits: a `429`, or a `403` carrying a `retry-after` header, an
  `x-ratelimit-remaining: 0`, or a secondary-rate-limit body message. A plain
  `403` (an authorization failure, not a rate limit) returns `false`, as does
  any other status.

  Shares the detection `retry/2` runs against a live `Req.Response`, so a
  caller working from an already-normalized `GhEx.Error` (which has no live
  response to re-inspect) reaches the same conclusion without re-deriving the
  logic. See `GhEx.Error.classify/1` and `GhEx.Error.retryable?/1`.
  """
  @spec rate_limited?(pos_integer() | nil, map() | nil, term()) :: boolean()
  def rate_limited?(429, _headers, _body), do: true
  def rate_limited?(403, headers, body), do: rate_limit_delay_ms(headers, body) != nil
  def rate_limited?(_status, _headers, _body), do: false

  defp rate_limit_delay_ms(headers, body) do
    cond do
      (after_s = header_int(headers, "retry-after")) != nil ->
        max(0, after_s) * 1000

      header_int(headers, "x-ratelimit-remaining") == 0 ->
        case header_int(headers, "x-ratelimit-reset") do
          nil -> nil
          reset -> max(0, reset - System.system_time(:second)) * 1000
        end

      secondary_rate_limit?(body) ->
        @secondary_delay_ms

      true ->
        nil
    end
  end

  # Req's `:retry` response step runs before `:decode_body`, so at retry time the
  # body is still the raw JSON string, not a decoded map: match the string (the
  # production case). The map clause covers an already-decoded body, e.g. when a
  # caller reorders steps, pre-decodes, or reads it back off a stored `GhEx.Error`.
  defp secondary_rate_limit?(body) when is_binary(body) do
    String.contains?(String.downcase(body), "secondary rate limit")
  end

  defp secondary_rate_limit?(%{"message" => message}) when is_binary(message) do
    String.contains?(String.downcase(message), "secondary rate limit")
  end

  defp secondary_rate_limit?(_body), do: false

  @doc """
  Computes how long to wait, in milliseconds, before the next request, given the
  rate-limit snapshot from a prior response's `meta`.

  Returns `0` when there is headroom (`remaining` above `:floor`), when the
  snapshot is `nil`, or when `remaining`/`reset` are absent. Otherwise returns the
  milliseconds until `reset` (clamped at `0` for an already-past reset), plus an
  optional `:buffer_ms`.

  This is a pure calculation; it never sleeps. The library deliberately leaves the
  wait to you, so you decide when and whether to block. Feed it the prior
  response's `meta.rate_limit` and act on the result:

      {:ok, _body, meta} = GhEx.REST.get(client, path)

      case GhEx.RateLimit.delay_until_reset(meta.rate_limit, floor: 50) do
        0 -> :ok
        ms -> Process.sleep(ms)
      end

  ## Options

    * `:floor` - wait when `remaining <= floor`. Defaults to `0` (wait only once
      the bucket is fully exhausted). A small positive floor (e.g. `50`) pauses
      while there is still headroom to spare.
    * `:buffer_ms` - added to a non-zero wait, to absorb clock skew. Defaults to `0`.
    * `:now` - the `DateTime` to measure from. Defaults to `DateTime.utc_now/0`;
      injectable in tests.

  ## Scope

  This guards the *next* call from a snapshot you thread in. It cannot pre-empt the
  first call of a session (there is no prior snapshot), and a single snapshot is a
  partial view when several processes share one token. `retry/2` remains the
  reactive backstop for calls that still hit the limit.
  """
  @spec delay_until_reset(t() | nil, keyword()) :: non_neg_integer()
  def delay_until_reset(snapshot, opts \\ [])

  def delay_until_reset(nil, _opts), do: 0

  def delay_until_reset(%__MODULE__{remaining: remaining, reset: reset}, opts) do
    floor = Keyword.get(opts, :floor, 0)

    cond do
      is_nil(remaining) or is_nil(reset) ->
        0

      remaining > floor ->
        0

      true ->
        now = Keyword.get(opts, :now, DateTime.utc_now())
        buffer = Keyword.get(opts, :buffer_ms, 0)
        max(0, DateTime.diff(reset, now, :millisecond)) + buffer
    end
  end

  @doc """
  Fetches rate-limit status from `GET /rate_limit`.

  This endpoint does not count against your rate limit. Returns the full body,
  whose `"resources"` map covers `core`, `search`, `graphql`, and others.
  """
  @spec get(GhEx.Client.t()) :: GhEx.REST.result()
  def get(client), do: GhEx.REST.get(client, "/rate_limit")

  # `headers` is a plain %{binary => [binary]} map, the shape both
  # `Req.Response.headers` and `GhEx.Error.headers` carry, so this works
  # whether the caller has a live response or an already-normalized error.
  defp header_str(headers, name) do
    case Map.get(headers || %{}, name, []) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp header_int(headers, name) do
    with value when is_binary(value) <- header_str(headers, name),
         {int, _} <- Integer.parse(value) do
      int
    else
      _ -> nil
    end
  end

  defp header_reset(headers) do
    case header_int(headers, "x-ratelimit-reset") do
      nil -> nil
      epoch -> DateTime.from_unix!(epoch)
    end
  end
end
