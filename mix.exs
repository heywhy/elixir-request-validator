defmodule RequestValidator.MixProject do
  use Mix.Project

  def project do
    [
      app: :request_validator,
      version: "0.1.1",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      description: description(),
      package: package(),

      # Docs
      name: "RequestValidator",
      source_url: "https://github.com/heywhy/elixir-request-validator",
      homepage_url: "https://github.com/heywhy/elixir-request-validator",
      docs: [
        main: "readme",
        extras: ["README.md", "LICENSE"]
      ]
    ]
  end

  defp description do
    """
    A blazing fast request validator for your phoenix app.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Atanda Rasheed"],
      licenses: ["MIT License"],
      links: %{
        "GitHub" => "https://github.com/heywhy/elixir-request-validator",
        "Docs" => "https://hexdocs.pm/request_validator/"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.10"},
      {:jason, "~> 1.2"},
      {:email_checker, "~> 0.1"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
