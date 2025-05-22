defmodule Test.Rivet.MigrationExternalTest do
  use Rivet.Case

  test "migration external" do
    assert {:ok, migs} = Rivet.Migration.Load.prepare_project_migrations([], :rivet)

    assert {:ok,
            [
              {30_000_000_000_000_000, RivetTestLib.Yoink.Migrations.Base},
              {40_000_000_000_000_000, Pinky.Base},
              {40_000_000_000_000_020, Pinky.Splat},
              {40_000_000_000_000_100, Pinky.Brain},
              {40_000_000_000_003_000, Pinky.Narf}
            ]} = Rivet.Migration.Load.to_ecto_migrations(migs)
  end
end
