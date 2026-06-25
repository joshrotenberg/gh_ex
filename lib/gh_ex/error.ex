defmodule GhEx.Error do
  @moduledoc """
  A normalized API error.

  Both transports collapse into this one shape. A REST call that returns a 4xx or
  5xx becomes a `GhEx.Error` carrying the status and GitHub's error body. A GraphQL
  call that returns a 200-with-`errors` body normalizes into the same struct via
  `from_graphql/2`.

  It is also an exception, so streaming helpers that cannot return an `:error`
  tuple can `raise` it.
  """

  defexception [:status, :message, :body, :errors, :documentation_url]

  @type t :: %__MODULE__{
          status: pos_integer() | nil,
          message: String.t() | nil,
          body: term(),
          errors: list() | nil,
          documentation_url: String.t() | nil
        }

  @doc """
  Builds an error from a failed REST response.

  Populates `:status`, `:message`, `:body`, `:errors`, and `:documentation_url`
  from the response status and JSON body. `:errors` is set when the body carries
  a top-level `"errors"` array.
  """
  @spec from_response(Req.Response.t()) :: t()
  def from_response(%Req.Response{status: status, body: body}) do
    %__MODULE__{
      status: status,
      message: extract(body, "message"),
      body: body,
      errors: extract(body, "errors"),
      documentation_url: extract(body, "documentation_url")
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
