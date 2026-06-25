defmodule GhEx.MixProject do
  use Mix.Project

  @version "0.2.1"
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
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_local_path: "priv/plts", plt_core_path: "priv/plts"]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
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
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
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
        Resources: [GhEx.Issues, GhEx.PullRequests, GhEx.Webhooks],
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
