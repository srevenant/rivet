defmodule Test.Rivet.MigrationIncludeTest do
  use Rivet.Case

  setup do
    opts = []
    cfg = [app: :rivet]
    assert {:ok, rivet_cfg} = Rivet.Config.build(opts, cfg)

    assert {:ok, model_cfg} =
             %{prefix: 200, include: "pinky"}
             |> Rivet.Migration.Load.prepare_model_config(rivet_cfg)

    %{
      model_cfg: model_cfg
    }
  end

  test "migration include", %{model_cfg: model_cfg} do
    state = %{idx: %{}, graph: :digraph.new([:acyclic, :private])}

    narf_path = Application.app_dir(:rivet, "priv/rivet/migrations/pinky/narf.exs")

    assert {:ok,
            %{
              idx: %{
                Pinky.Base => %Rivet.Migration{
                  base: true,
                  index: 20_000_000_000_000_000,
                  module: Pinky.Base,
                  parent: Pinky,
                  after: nil,
                  prefix: 200,
                  version: 0
                },
                Pinky.Splat => %Rivet.Migration{
                  base: false,
                  index: 20_000_000_000_000_020,
                  module: Pinky.Splat,
                  parent: Pinky,
                  after: RivetTestLib.Yoink.Migrations.Base,
                  prefix: 200,
                  version: 20
                },
                Pinky.Brain => %Rivet.Migration{
                  base: true,
                  index: 20_000_000_000_000_100,
                  module: Pinky.Brain,
                  parent: Pinky,
                  after: nil,
                  prefix: 200,
                  version: 100
                },
                Pinky.Narf => %Rivet.Migration{
                  base: false,
                  index: 20_000_000_000_003_000,
                  module: Pinky.Narf,
                  parent: Pinky,
                  after: Pinky.Brain,
                  path: ^narf_path,
                  prefix: 200,
                  version: 3000
                }
              }
            }} =
             Rivet.Migration.Load.merge_model_migrations(
               {:ok, state},
               model_cfg,
               "index.exs",
               true
             )
  end

  test "cyclic migrations fail", %{model_cfg: model_cfg} do
    state = %{idx: %{}, graph: :digraph.new([:acyclic, :private])}

    assert_raise Ecto.MigrationError,
                 "Module Pinky.Narf depends on itself: Pinky.Narf -> Pinky.Brain -> Pinky.Splat -> Pinky.Narf",
                 fn ->
                   Rivet.Migration.Load.merge_model_migrations(
                     {:ok, state},
                     model_cfg,
                     "cycle.exs",
                     true
                   )
                 end
  end
end
