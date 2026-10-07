defmodule Rivet do
  @moduledoc """
  ***This project is still a "Work in Progress" and not ready for GA***

  [Rivets](https://docs.google.com/document/d/1ntoTA9YRE7KvKpmwZRtfzKwTZNgo2CY6YfJnDNQAlBc) is an opinionated framework for managing data models in Elixir.

  `Rivet` is a series of helper libraries for elixir applications wanting help in their Rivets projects.
  """

  defmacro __using__(_) do
    quote do
      @type rivet_config :: %{
              app: String.t(),
              base: atom(),
              base_path: String.t(),
              models_root: String.t(),
              opts: Keyword.t(),
              tests_root: String.t()
            }
      @type rivet_error :: {:error, String.t() | atom()}
      @type rivet_migration_state :: %{
              idx: %{integer() => Rivet.Migration.t()},
              mods: %{atom() => list()}
            }
      @type rivet_migration_input_include :: %{include: module(), prefix: integer()}
      @type rivet_migration_input_external :: %{
              external: String.t(),
              migrations: list(rivet_migration_input_include())
            }
      @type rivet_migration_input_model :: map()
      # %{
      #         base: true | false,
      #         version: integer(),
      #         module: module()
      #       }
      @type rivet_migration_input_any() ::
              rivet_migration_input_include()
              | rivet_migration_input_external()
              | rivet_migration_input_model()
      @type rivet_migrations :: list(Rivet.Migration.t())
      @type rivet_state_result() :: {:ok, rivet_migration_state()} | rivet_error()

      @migrations_file "migrations.exs"
      @index_file "index.exs"
      @archive_file "archive.exs"
    end
  end
end
