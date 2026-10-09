defmodule App2.MixProject do
  use Mix.Project

  def project do
    [
      app: :app2,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      env: [
        rivet: [
          app: :app2
        ]
      ],
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # {:rivet, "~> 1.0.0"}
    ]
  end
end
