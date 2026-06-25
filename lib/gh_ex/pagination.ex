defmodule GhEx.Pagination do
  @moduledoc """
  REST pagination via the `Link` header.

  GitHub returns pagination as a `Link` header listing `next`, `prev`, `first`,
  and `last` URLs. This module parses that header into a map. `GhEx.REST.stream/3`
  is the high-level consumer; use `links/1` directly when you want to drive
  pagination yourself.

  GraphQL cursor pagination is handled separately by `GhEx.GraphQL.stream/4`.
  """

  @link_re ~r/<(?<url>[^>]+)>\s*;\s*rel="(?<rel>[^"]+)"/

  @doc """
  Parses the `Link` header of a response into a `%{rel => url}` map.

  Returns an empty map when the header is absent.

  ## Examples

      iex> resp = %Req.Response{
      ...>   headers: %{"link" => [~s(<https://api.github.com/x?page=2>; rel="next", <https://api.github.com/x?page=9>; rel="last")]}
      ...> }
      iex> GhEx.Pagination.links(resp)
      %{"next" => "https://api.github.com/x?page=2", "last" => "https://api.github.com/x?page=9"}
  """
  @spec links(Req.Response.t()) :: %{optional(String.t()) => String.t()}
  def links(%Req.Response{} = resp) do
    case Req.Response.get_header(resp, "link") do
      [value | _] -> parse(value)
      [] -> %{}
    end
  end

  @doc """
  Parses a raw `Link` header value into a `%{rel => url}` map.

  ## Examples

      iex> GhEx.Pagination.parse(~s(<https://api.github.com/x?page=2>; rel="next"))
      %{"next" => "https://api.github.com/x?page=2"}
  """
  @spec parse(String.t()) :: %{optional(String.t()) => String.t()}
  def parse(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.flat_map(fn segment ->
      case Regex.named_captures(@link_re, String.trim(segment)) do
        %{"url" => url, "rel" => rel} -> [{rel, url}]
        nil -> []
      end
    end)
    |> Map.new()
  end
end
