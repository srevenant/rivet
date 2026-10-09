ExUnit.start(capture_log: true)

# {:ok, _} = Application.ensure_all_started(:ex_machina)
Supervisor.start_link([Rivet.Test.Repo], strategy: :one_for_one)

# ExUnit.configure(exclude: [pending: true], formatters: [JUnitFormatter, ExUnit.CLIFormatter])

Ecto.Adapters.SQL.Sandbox.mode(Rivet.Test.Repo, :manual)
# Faker.start()

Code.require_file(
  "test/fixtures/rivet/lib/rivet/test_table/model.ex",
  File.cwd!()
)
