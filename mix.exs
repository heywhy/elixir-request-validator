defmodule Request.Validator.Mixfile do
  use Mix.Project

  @version "0.8.1"
  @scm_url "https://github.com/heywhy/elixir-request-validator"

  def project do
    [
      app: :request_validator,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: [
        files: ["lib", "mix.exs", "CHANGELOG.md", "README.md"],
        maintainers: ["Atanda Rasheed"],
        licenses: ["MIT License"],
        links: %{
          "GitHub" => @scm_url,
          "Docs" => "https://hexdocs.pm/request_validator/"
        }
      ],
      description: """
        A blazing fast request validator for your phoenix app.
      """,

      # Docs
      name: "RequestValidator",
      source_url: @scm_url,
      homepage_url: "https://hexdocs.pm/request_validator/",
      docs: [
        main: "readme",
        extras: ["README.md", "LICENSE"]
      ],

      # Coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: []
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:ecto, "~> 3.9", optional: true},
      {:email_checker, "~> 0.2"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:excoveralls, "~> 0.15", only: :test},
      {:git_hooks, "~> 0.7", only: :dev, runtime: false},
      {:git_ops, "~> 2.5", only: :dev},
      {:jason, "~> 1.4", optional: true},
      {:plug, "~> 1.14", only: :test, optional: true}
    ]
  end

  defp aliases do
    [
      "ops.release": ["cmd mix test --color", "git_ops.release"],
      setup: ["deps.get", "git_hooks.install"]
    ]
  end
end
