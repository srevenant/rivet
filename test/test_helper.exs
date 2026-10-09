ExUnit.start(capture_log: true)

Supervisor.start_link([Rivet.Test.Repo], strategy: :one_for_one)

Ecto.Adapters.SQL.Sandbox.mode(Rivet.Test.Repo, :manual)

# # &()#. windows paths
# prefix = String.split("test/fixtures/rivet/lib/rivet", "/") |> Path.join()
#
# ## hardwiring the load of the fixtures because I don't want them in the support
# ## load for reasons(tm)
# [
#   "test_search.ex",
#   Path.join("test_table", "model.ex"),
#   Path.join("test_table", "search.ex")
# ]
# |> Enum.each(fn f -> Code.require_file(Path.join([prefix, f]), File.cwd!()) end)
