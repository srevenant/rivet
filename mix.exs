defmodule Rivet.MixProject do
  use Mix.Project

  def project do
    [
      app: :rivet,
      version: "3.0.0",
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
      xref: [exclude: List.wrap(Application.get_env(:rivet, :repo))],
      compilers: [:es6_maps | Mix.compilers()]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [rivet: [app: :rivet] ++ rivet_env(Mix.env())],
      mod: {Rivet.Application, []}
    ]
  end

  defp rivet_env(:test),
    do: [
      lib_dir: "test/fixtures/rivet/lib",
      priv_dir: "test/fixtures/rivet/priv",
      app1_override: "test/fixtures/app1",
      app2_override: "test/fixtures/app2"
    ]

  defp rivet_env(_), do: []

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "rivet migrate", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      # keystrokes of life
      c: ["compile"]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ecto_enum, "~> 1.4"},
      {:ecto_sql, "~> 3.13"},
      {:es6_maps, "~> 1.0.2"},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.4", only: [:dev, :test], runtime: false},
      {:postgrex, "~> 0.22.4"},
      # {:rivet_utils, "~> 2.0"},
      {:rivet_utils, git: "https://github.com/srevenant/rivet-utils/", branch: "v3"},
      # not used but this hels things test properly
      {:app1, path: "test/fixtures/app1", only: :test, runtime: false},
      {:app2, path: "test/fixtures/app2", only: :test, runtime: false},
      {:transmogrify, "~> 2.0"},
      {:typed_ecto_schema, "~> 0.4", runtime: false},
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
