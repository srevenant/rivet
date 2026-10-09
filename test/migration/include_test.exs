defmodule Rivet.Test.Migration.IncludeTest do
  use Rivet.Test.Case

  test "migration include" do
    opts = [
      lib_dir: "test/fixtures/app1/lib",
      priv_dir: "test/fixtures/app1/priv"
    ]

    cfg = [app: :app1]
    assert {:ok, rivet_cfg} = Rivet.Config.build(opts, cfg)

    assert {:ok, model_cfg} =
             Rivet.Migration.Load.prepare_model_config(
               %{prefix: 200, include: "pinky"},
               rivet_cfg.optsd.mig_dir
             )

    state = %{idx: %{}, mods: %{}}

    narf_path = "test/fixtures/app1/priv/rivet/migrations/pinky/narf.exs"

    assert {:ok,
            %{
              idx: %{
                20_000_000_000_000_000 => %Rivet.Migration{
                  base: true,
                  index: 20_000_000_000_000_000,
                  module: App1.Pinky.Base,
                  parent: Pinky,
                  prefix: 200,
                  version: 0
                },
                20_000_000_000_000_020 => %Rivet.Migration{
                  base: false,
                  index: 20_000_000_000_000_020,
                  module: App1.Pinky.Splat,
                  parent: Pinky,
                  prefix: 200,
                  version: 20
                },
                20_000_000_000_000_100 => %Rivet.Migration{
                  base: true,
                  index: 20_000_000_000_000_100,
                  module: App1.Pinky.Brain,
                  parent: Pinky,
                  prefix: 200,
                  version: 100
                },
                20_000_000_000_003_000 => %Rivet.Migration{
                  base: false,
                  index: 20_000_000_000_003_000,
                  module: App1.Pinky.Narf,
                  parent: Pinky,
                  path: ^narf_path,
                  prefix: 200,
                  version: 3000
                }
              },
              mods: %{
                App1.Pinky.Base => [],
                App1.Pinky.Brain => [],
                App1.Pinky.Narf => [],
                App1.Pinky.Splat => []
              }
            }} =
             Rivet.Migration.Load.merge_model_migrations(
               {:ok, state},
               model_cfg,
               "index.exs",
               true
             )
  end
end
