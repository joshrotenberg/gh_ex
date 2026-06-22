defmodule GH do
  @moduledoc """
  A modern, Req-based client for the GitHub REST and GraphQL APIs.

  The design is *core over catalog*: a small generic core reaches every GitHub
  endpoint, and typed convenience modules are added by demand rather than as a
  coverage obligation. See `SPEC.md` for the full rationale.

  ## Quick start

      client = GH.new(auth: {:token, System.fetch_env!("GITHUB_TOKEN")})

      # generic REST, full coverage
      {:ok, issues, meta} =
        GH.REST.get(client, "/repos/elixir-lang/elixir/issues", params: [state: "open"])

      # auto-paginated stream of every open issue
      client
      |> GH.REST.stream("/repos/elixir-lang/elixir/issues", params: [state: "open"])
      |> Enum.take(100)

  The public namespace is `GH` for now. It is provisional and may become `GhEx`
  before the first release; see the naming note in `SPEC.md`.
  """

  alias GH.Client

  @doc """
  Builds a new `GH.Client`.

  ## Options

    * `:auth` - a `t:GH.Auth.t/0` value, e.g. `{:token, "ghp_..."}`. Defaults to `nil`.
    * `:rest_url` - REST base URL. Defaults to `"https://api.github.com"`.
    * `:graphql_url` - GraphQL endpoint. Defaults to `"https://api.github.com/graphql"`.
    * `:req_options` - extra options merged into every `Req` request. Useful for
      `Req.Test` plugs, custom Finch pools, retries, and base-URL overrides for
      GitHub Enterprise Server.

  ## Examples

      iex> client = GH.new(auth: {:token, "secret"})
      iex> client.rest_url
      "https://api.github.com"
  """
  @spec new(keyword()) :: Client.t()
  def new(opts \\ []), do: Client.new(opts)
end
