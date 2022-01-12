defmodule Request.Validator.Mixfile do
  use Mix.Project

  @source_url "https://github.com/heywhy/elixir-request-validator"

  def project do
    [
      app: :request_validator,
      version: "0.6.6",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers(),
      description: description(),
      package: package(),

      # Docs
      name: "RequestValidator",
      source_url: @source_url,
      homepage_url: "https://hexdocs.pm/request_validator/",
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
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/request_validator/"
      }
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
      {:plug, "~> 1.10"},
      {:jason, "~> 1.2"},
      {:ecto, "~> 3.5"},
      {:email_checker, "~> 0.1"},
      {:ex_phone_number,
       git: "https://github.com/ukchukx/ex_phone_number.git", branch: "develop"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
