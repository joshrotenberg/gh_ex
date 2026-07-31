defmodule GhEx.Error do
  @moduledoc """
  A normalized API error.

  Both transports collapse into this one shape. A REST call that returns a 4xx or
  5xx becomes a `GhEx.Error` carrying the status and GitHub's error body. A GraphQL
  call that returns a 200-with-`errors` body normalizes into the same struct via
  `from_graphql/2`.

  It is also an exception, so streaming helpers that cannot return an `:error`
  tuple can `raise` it.

  `classify/1` and `retryable?/1` sort an already-returned error (a
  `GhEx.Error` or the raw transport exception `t:GhEx.REST.result/0` and
  `t:GhEx.GraphQL.result/0` can also carry) into a coarse taxonomy, for a
  caller such as a job queue deciding whether to retry, back off, or discard.
  """

  alias GhEx.RateLimit

  defexception [:status, :message, :body, :errors, :documentation_url, :headers]

  @type t :: %__MODULE__{
          status: pos_integer() | nil,
          message: String.t() | nil,
          body: term(),
          errors: list() | nil,
          documentation_url: String.t() | nil,
          headers: map() | nil
        }

  @typedoc """
  The coarse classification `classify/1` sorts an error into.

    * `:rate_limited` - a `429`, or a `403` that `GhEx.RateLimit` recognizes as
      a primary or secondary rate limit. Worth waiting out and retrying.
    * `:permission` - a `401` or a plain `403` (not a rate limit): the token
      lacks the scope or access. Retrying without a credential change cannot
      succeed.
    * `:not_found` - a `404` or a `410` (gone): the resource is not there,
      permanently as far as the caller is concerned.
    * `:validation` - a `4xx` describing a problem with the request itself
      (`422` failed semantic validation, `400` bad request, and any other
      unrecognized `4xx`), or a GraphQL 200-with-`errors` response (no HTTP
      status to classify by). Retrying the same request cannot succeed; the
      caller must change it.
    * `:server` - a `408`, or a `5xx`: GitHub's side, generally transient.
    * `:transport` - not a `GhEx.Error` at all, but the raw `Req`/`Mint`
      exception returned for a connection failure.
  """
  @type classification ::
          :rate_limited | :permission | :not_found | :validation | :server | :transport

  @doc """
  Builds an error from a failed REST response.

  Populates `:status`, `:message`, `:body`, `:errors`, and `:documentation_url`
  from the response status and JSON body. `:errors` is set when the body carries
  a top-level `"errors"` array. `:headers` keeps the response's headers (the
  same `%{binary => [binary]}` shape `Req.Response.headers` uses), so
  `classify/1` and `retryable?/1` can disambiguate a `403` after the fact,
  without a live response to re-inspect.
  """
  @spec from_response(Req.Response.t()) :: t()
  def from_response(%Req.Response{status: status, body: body, headers: headers}) do
    %__MODULE__{
      status: status,
      message: extract(body, "message"),
      body: body,
      errors: extract(body, "errors"),
      documentation_url: extract(body, "documentation_url"),
      headers: headers
    }
  end

  @doc """
  Builds an error from a GraphQL 200-with-`errors` response.

  GraphQL returns HTTP 200 even on failure, with the failures in an `errors`
  array and any partial result in `data`. Both are preserved: `:errors` holds the
  array, `:message` is the first error's message, and `:body` carries the whole
  `%{"data" => ..., "errors" => ...}` envelope so partial data stays reachable.
  """
  @spec from_graphql(list(), term()) :: t()
  def from_graphql(errors, data) when is_list(errors) do
    %__MODULE__{
      status: nil,
      message: errors |> List.first(%{}) |> extract("message"),
      body: %{"data" => data, "errors" => errors},
      errors: errors,
      documentation_url: nil
    }
  end

  @doc """
  Builds an error from a GraphQL HTTP 200 whose body is not a JSON object.

  GitHub's GraphQL endpoint answers 200 with a JSON object envelope; a list,
  scalar, or `nil` body cannot carry `data`/`errors` and is unusable. `:status`
  is left `nil` (the HTTP 200 is not the error) and the raw body is preserved on
  `:body` for diagnostics.
  """
  @spec from_graphql_shape(term()) :: t()
  def from_graphql_shape(body) do
    %__MODULE__{
      status: nil,
      message: "GraphQL response body was not a JSON object",
      body: body,
      errors: nil,
      documentation_url: nil
    }
  end

  @doc """
  Classifies an error into a `t:classification/0`.

  Accepts a `%GhEx.Error{}` or the raw transport exception a REST or GraphQL
  call's error arm can carry instead (`t:GhEx.REST.result/0`,
  `t:GhEx.GraphQL.result/0`). The `403` disambiguation (rate limit vs plain
  permission denial) reuses `GhEx.RateLimit.rate_limited?/3`, the same check
  `GhEx.RateLimit.retry/2` runs against a live response, so the two never
  disagree.

  ## Examples

      iex> GhEx.Error.classify(%GhEx.Error{status: 429})
      :rate_limited

      iex> GhEx.Error.classify(%GhEx.Error{
      ...>   status: 403,
      ...>   headers: %{"x-ratelimit-remaining" => ["0"], "x-ratelimit-reset" => ["9999999999"]}
      ...> })
      :rate_limited

      iex> GhEx.Error.classify(%GhEx.Error{status: 403})
      :permission

      iex> GhEx.Error.classify(%GhEx.Error{status: 404})
      :not_found

      iex> GhEx.Error.classify(%GhEx.Error{status: 410})
      :not_found

      iex> GhEx.Error.classify(%GhEx.Error{status: 422})
      :validation

      iex> GhEx.Error.classify(%GhEx.Error{status: nil})
      :validation

      iex> GhEx.Error.classify(%GhEx.Error{status: 503})
      :server

      iex> GhEx.Error.classify(%RuntimeError{})
      :transport
  """
  @spec classify(t() | Exception.t()) :: classification()
  def classify(%__MODULE__{status: status, headers: headers, body: body}) do
    cond do
      RateLimit.rate_limited?(status, headers, body) -> :rate_limited
      status in [401, 403] -> :permission
      status in [404, 410] -> :not_found
      status == 408 or (is_integer(status) and status >= 500) -> :server
      true -> :validation
    end
  end

  def classify(exception) when is_exception(exception), do: :transport

  @doc """
  Whether an error is worth retrying, consistent with
  `GhEx.RateLimit.retry/2`.

  True for `:rate_limited` and for the same transient-server statuses
  `retry/2` retries (`408`, `500`, `502`, `503`, `504`). False for
  `:permission`, `:not_found`, `:validation`, any other status, and for a raw
  transport exception: `retry/2` does not retry those either (a connection
  failure is left to the caller or the underlying transport, not this
  policy), so `retryable?/1` reports the same `false` here rather than
  guessing at a different answer than the retry hook actually in effect.

  ## Examples

      iex> GhEx.Error.retryable?(%GhEx.Error{status: 429})
      true

      iex> GhEx.Error.retryable?(%GhEx.Error{status: 503})
      true

      iex> GhEx.Error.retryable?(%GhEx.Error{status: 403})
      false

      iex> GhEx.Error.retryable?(%GhEx.Error{status: 404})
      false

      iex> GhEx.Error.retryable?(%RuntimeError{})
      false
  """
  @spec retryable?(t() | Exception.t()) :: boolean()
  def retryable?(%__MODULE__{status: status, headers: headers, body: body}) do
    RateLimit.rate_limited?(status, headers, body) or status in [408, 500, 502, 503, 504]
  end

  def retryable?(exception) when is_exception(exception), do: false

  @impl true
  def message(%__MODULE__{status: status, message: msg}) do
    "GitHub API error" <> status_part(status) <> message_part(msg)
  end

  defp status_part(nil), do: ""
  defp status_part(status), do: " (HTTP #{status})"

  defp message_part(nil), do: ""
  defp message_part(msg), do: ": " <> msg

  defp extract(body, key) when is_map(body), do: Map.get(body, key)
  defp extract(_body, _key), do: nil
end
