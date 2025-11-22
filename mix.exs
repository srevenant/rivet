defmodule Rivet.MixProject do
  use Mix.Project

  def project do
    [
      app: :rivet,
      version: "2.7.1",
      elixir: "~> 1.18",
      description: "Elixir data model framework library",
      source_url: "https://github.com/srevenant/rivet",
      docs: [main: "Rivet"],
      package: package(),
      deps: deps(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_apps: [:mix],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      xref: [exclude: List.wrap(Application.get_env(:rivet, :repo))]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [rivet: [app: :rivet]],
      mod: {Rivet.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    # keystrokes of life
    [c: ["compile"]]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ecto_enum, "~> 1.4"},
      {:ecto_sql, "~> 3.13"},
      {:timex, "~> 3.7", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.4", only: :test, runtime: false},
      {:postgrex, "~> 0.21", only: :test},
      {:rivet_utils, "~> 2.0"},
      {:transmogrify, "~> 2.0"},
      {:typed_ecto_schema, "~> 0.4"},
      {:yaml_elixir, "~> 2.12"}
    ]
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/srevenant/rivet"},
      source_url: "https://github.com/srevenant/rivet"
    ]
  end
end
