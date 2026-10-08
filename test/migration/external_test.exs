defmodule Rivet.Test.Migration.ExternalTest do
  use Rivet.Test.Case

  test "migration external" do
    opts = [
      lib_dir: "test/fixtures/rivet/lib",
      # models_dir: "test_app",
      priv_dir: "test/fixtures/rivet/priv"
    ]

    assert {:ok, migs} = Rivet.Migration.Load.prepare_project_migrations(opts, :rivet)

    assert {:ok,
            [
              {30_000_000_000_000_000, TestApp.Yoink.Migrations.Base},
              {40_000_000_000_000_000, Pinky.Base},
              {40_000_000_000_000_020, Pinky.Splat},
              {40_000_000_000_000_100, Pinky.Brain},
              {40_000_000_000_003_000, Pinky.Narf}
            ]} = Rivet.Migration.Load.to_ecto_migrations(migs)
  end
end
