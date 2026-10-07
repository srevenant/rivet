defmodule Rivet.Test.Migration.LoadTest do
  use Rivet.Test.Case
  import Rivet.Migration

  test "load_data_file" do
    assert {:error, "Cannot find file 'nar'"} = load_data_file("nar")

    File.write("test/.input", "")
    on_exit(fn -> File.rm("test/.input") end)

    assert {:error, "Cannot load file 'test/.input': Invalid contents"} =
             load_data_file("test/.input")

    # force an error
    assert {:error,
            "Cannot load file 'LICENSE.txt': keyword argument must be followed by space after: http:"} =
             load_data_file("LICENSE.txt")
  end
end
