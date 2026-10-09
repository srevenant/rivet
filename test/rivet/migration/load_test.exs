defmodule Rivet.Test.Migration.LoadTest do
  use Rivet.Test.Case
  import Rivet.Migration

  test "load_data_file" do
    assert {:error, "Cannot find file 'nar'"} = load_data_file("nar")

    # prefer test/.tmp for observability
    tmp = Path.join(["test", ".tmp", "load"])
    File.mkdir_p!(tmp)
    path = Path.join(tmp, "input")
    File.write(path, "")

    on_exit(fn -> File.rm_rf!(tmp) end)

    error = "Cannot load file '#{path}': Invalid contents"
    assert {:error, ^error} = load_data_file(path)

    # force an error
    assert {:error,
            "Cannot load file 'LICENSE.txt': keyword argument must be followed by space after: http:"} =
             load_data_file("LICENSE.txt")

    Process.sleep(1000)
  end
end
