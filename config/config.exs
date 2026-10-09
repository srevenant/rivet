import Config

config :logger, level: :info

config :rivet,
  ecto_repos: [Rivet.Test.Repo],
  table_prefix: "",
  repo: Rivet.Test.Repo

config :mix_test_watch,
  exclude: [
    ~r{test/fixtures/},
    ~r{_build/},
    ~r{test/\.tmp/}
  ]

import_config "#{config_env()}.exs"
