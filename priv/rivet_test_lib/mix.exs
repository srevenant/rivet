defmodule RivetTestLib.MixProject do
  use Mix.Project

  def project do
    [
      app: :rivet_test_lib,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      rivet: [
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
      {:rivet, "~> 1.0.0"}
    ]
  end
end
