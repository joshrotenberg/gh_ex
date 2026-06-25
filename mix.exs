defmodule GhEx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/joshrotenberg/gh_ex"

  def project do
    [
      app: :gh_ex,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "gh_ex",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.16", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "A Req-based Elixir client for the GitHub REST and GraphQL APIs."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib guides mix.exs .formatter.exs README.md CHANGELOG.md SPEC.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/authentication.md",
        "guides/pagination.md",
        "guides/error-handling.md",
        "guides/github-enterprise-server.md",
        "guides/testing.md",
        "CHANGELOG.md",
        "SPEC.md"
      ],
      groups_for_extras: [
        Guides: ~r"guides/"
      ],
      groups_for_modules: [
        Core: [GhEx, GhEx.Client, GhEx.REST, GhEx.GraphQL],
        Resources: [GhEx.Issues, GhEx.PullRequests],
        Authentication: [GhEx.Auth, GhEx.JWT, GhEx.App, GhEx.TokenCache, GhEx.TokenCache.ETS],
        "Pagination & metadata": [
          GhEx.Pagination,
          GhEx.RateLimit,
          GhEx.Error,
          GhEx.REST.Meta,
          GhEx.GraphQL.Meta
        ]
      ]
    ]
  end
end
