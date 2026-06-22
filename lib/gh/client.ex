defmodule GH.Client do
  @moduledoc """
  The client struct: credentials, endpoints, and per-request `Req` options.

  Build one with `GH.new/1` rather than constructing the struct by hand.
  The same client is used for both REST (`GH.REST`) and, later, GraphQL.
  """

  @default_rest_url "https://api.github.com"
  @default_graphql_url "https://api.github.com/graphql"

  @type t :: %__MODULE__{
          auth: GH.Auth.t() | nil,
          rest_url: String.t(),
          graphql_url: String.t(),
          req_options: keyword()
        }

  defstruct auth: nil,
            rest_url: @default_rest_url,
            graphql_url: @default_graphql_url,
            req_options: []

  @doc """
  Builds a client from options. See `GH.new/1` for the option list.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      auth: Keyword.get(opts, :auth),
      rest_url: Keyword.get(opts, :rest_url, @default_rest_url),
      graphql_url: Keyword.get(opts, :graphql_url, @default_graphql_url),
      req_options: Keyword.get(opts, :req_options, [])
    }
  end
end
