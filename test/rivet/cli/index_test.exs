defmodule Rivet.Test.Cli.IndexTest do
  use Rivet.Test.Case
  import ExUnit.CaptureIO

  def read_first_line(file) do
    File.open!(file, fn f -> IO.read(f, :line) end)
  end

  setup do
    # prefer test/.tmp for observability
    tmp = ["test", ".tmp", "cli"]

    on_exit(fn -> File.rm_rf!(Path.join(tmp)) end)

    dirs =
      Map.new(["lib", "priv", "test"], fn d ->
        path = Path.join(tmp ++ [d])
        File.mkdir_p!(path)
        {String.to_atom(d), path}
      end)

    File.mkdir_p!(Path.join([dirs.lib, "rivet"]))
    opts = ["--lib-dir", dirs.lib, "--priv-dir", dirs.priv, "--test-dir", dirs.test]

    {:ok, %{dirs, opts}}
  end

  describe "Rivet New" do
    test "single path segment", %{opts, dirs: %{lib}} do
      assert capture_io(fn ->
               Mix.Tasks.Rivet.New.run(opts ++ ["--no-migration", "model", "single"])
             end) =~ "creating"

      created = "#{lib}/rivet/single"
      assert {:ok, files} = File.ls(created)
      assert 8 == length(files)

      assert "defmodule Rivet.Single do\n" = Path.join(created, "model.ex") |> read_first_line()

      Process.sleep(1000)
    end

    test "multiple path segments", %{opts, dirs: %{lib}} do
      assert capture_io(fn ->
               Mix.Tasks.Rivet.New.run(opts ++ ["--no-migration", "model", "multiple/segments"])
             end) =~ "creating"

      created = "#{lib}/rivet/multiple/segments"
      assert {:ok, files} = File.ls(created)
      assert 8 == length(files)

      assert "defmodule Rivet.Multiple.Segments do\n" =
               Path.join(created, "model.ex") |> read_first_line()
    end
  end
end
