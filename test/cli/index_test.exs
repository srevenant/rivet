defmodule Test.Rivet.RivetCliTest do
  use Rivet.Case
  import ExUnit.CaptureIO

  def read_first_line(file) do
    File.open!(file, fn f -> IO.read(f, :line) end)
  end

  setup do
    Application.put_env(:rivet, :rivet, app: :rivet)

    tmp = temp_dir()
    on_exit(fn -> File.rm_rf!(tmp) end)

    Path.join(tmp, "lib/rivet") |> File.mkdir_p!()
    Path.join(tmp, "test/rivet") |> File.mkdir_p!()
    lib = Path.join(tmp, "lib")
    tst = Path.join(tmp, "test")
    %{base: tmp, lib: lib, tst: tst}
  end

  describe "Rivet New" do
    test "single path segment", dirs do
      assert capture_io(fn ->
               Mix.Tasks.Rivet.New.run([
                 "--lib-dir",
                 dirs.lib,
                 "--test-dir",
                 dirs.tst,
                 "--no-migration",
                 "model",
                 "single"
               ])
             end) =~ "creating"

      created = Path.join(dirs.lib, "rivet/single")
      assert {:ok, files} = File.ls(created)
      assert 8 == length(files)

      assert "defmodule Rivet.Single do\n" = Path.join(created, "model.ex") |> read_first_line()
    end

    test "multiple path segments", dirs do
      capture_io(fn ->
        Mix.Tasks.Rivet.New.run([
          "--lib-dir",
          dirs.lib,
          "--test-dir",
          dirs.tst,
          "--no-migration",
          "model",
          "multiple/segments"
        ])
      end) =~ "creating"

      created = Path.join(dirs.lib, "rivet/multiple/segments")
      assert {:ok, files} = File.ls(created)
      assert 8 == length(files)

      assert "defmodule Rivet.Multiple.Segments do\n" =
               Path.join(created, "model.ex") |> read_first_line()
    end
  end
end
