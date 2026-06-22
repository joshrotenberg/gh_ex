defmodule GH.Error do
  @moduledoc """
  A normalized API error.

  Both transports collapse into this one shape. A REST call that returns a 4xx or
  5xx becomes a `GH.Error` carrying the status and GitHub's error body. (GraphQL's
  200-with-`errors` body will normalize into the same struct in M2.)

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

  @doc false
  def from_response(%Req.Response{status: status, body: body}) do
    %__MODULE__{
      status: status,
      message: extract(body, "message"),
      body: body,
      errors: extract(body, "errors"),
      documentation_url: extract(body, "documentation_url")
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
