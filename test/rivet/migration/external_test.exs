defmodule Rivet.Test.Migration.ExternalTest do
  use Rivet.Test.Case

  test "migration external" do
    opts = [
      lib_dir: "test/fixtures/app1/lib",
      priv_dir: "test/fixtures/app1/priv",
      app2_override: "test/fixtures/app2"
    ]

    assert {:ok, migs} = Rivet.Migration.Load.prepare_project_migrations(opts, :app1)

    assert {:ok,
            [
              {30_000_000_000_000_000, App2.Yoink.Migrations.Base},
              {40_000_000_000_000_000, App1.Pinky.Base},
              {40_000_000_000_000_020, App1.Pinky.Splat},
              {40_000_000_000_000_100, App1.Pinky.Brain},
              {40_000_000_000_003_000, App1.Pinky.Narf}
            ]} = Rivet.Migration.Load.to_ecto_migrations(migs)
  end
end
