defmodule GhEx do
  @moduledoc """
  A Req-based client for the GitHub REST and GraphQL APIs.

  A small generic core (`GhEx.REST` and `GhEx.GraphQL`) reaches every GitHub
  endpoint. Typed convenience modules are added as needed rather than for full
  endpoint coverage. See `SPEC.md` for the design rationale.

  ## Quick start

      client = GhEx.new(auth: {:token, System.fetch_env!("GITHUB_TOKEN")})

      # generic REST, full coverage
      {:ok, issues, meta} =
        GhEx.REST.get(client, "/repos/elixir-lang/elixir/issues", params: [state: "open"])

      # auto-paginated stream of every open issue
      client
      |> GhEx.REST.stream("/repos/elixir-lang/elixir/issues", params: [state: "open"])
      |> Enum.take(100)

  The public namespace is `GhEx`, matching the `gh_ex` package name.
  """

  alias GhEx.Client

  @doc """
  Builds a new `GhEx.Client`.

  ## Options

    * `:auth` - a `t:GhEx.Auth.t/0` value, e.g. `{:token, "ghp_..."}`. Defaults to `nil`.
    * `:rest_url` - REST base URL. Defaults to `"https://api.github.com"`.
    * `:graphql_url` - GraphQL endpoint. Defaults to `"https://api.github.com/graphql"`.
    * `:req_options` - extra options merged into every `Req` request. Useful for
      `Req.Test` plugs, custom Finch pools, retries, and base-URL overrides for
      GitHub Enterprise Server.

  ## Examples

      iex> client = GhEx.new(auth: {:token, "secret"})
      iex> client.rest_url
      "https://api.github.com"
  """
  @spec new(keyword()) :: Client.t()
  def new(opts \\ []), do: Client.new(opts)
end
