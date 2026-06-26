defmodule GhEx.Client do
  @moduledoc """
  The client struct: credentials, endpoints, and per-request `Req` options.

  Build one with `GhEx.new/1` rather than constructing the struct by hand.
  The same client is used for both REST (`GhEx.REST`) and, later, GraphQL.

  > #### Credentials are redacted from inspect output {: .info}
  >
  > The `:auth` field holds a secret (a bearer token, or a GitHub App's RSA
  > private key) and is excluded from `Inspect`, so it never appears in
  > `inspect/1`, IEx echoes, or a crash report that captures the call args.
  > Do not defeat this by logging `client.auth` or interpolating the raw
  > credential yourself.
  """

  @default_rest_url "https://api.github.com"
  @default_graphql_url "https://api.github.com/graphql"

  @type t :: %__MODULE__{
          auth: GhEx.Auth.t() | nil,
          rest_url: String.t(),
          graphql_url: String.t(),
          req_options: keyword()
        }

  @derive {Inspect, except: [:auth]}
  defstruct auth: nil,
            rest_url: @default_rest_url,
            graphql_url: @default_graphql_url,
            req_options: []

  @doc """
  Builds a client from options. See `GhEx.new/1` for the option list.
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
