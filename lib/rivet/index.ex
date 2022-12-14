defmodule Rivet do
  @moduledoc """
  ***This project is still a "Work in Progress" and not ready for GA***

  [Rivets](https://docs.google.com/document/d/1ntoTA9YRE7KvKpmwZRtfzKwTZNgo2CY6YfJnDNQAlBc) is an opinionated framework for managing data models in Elixir.

  `Rivet` is a series of helper libraries for elixir applications wanting help in their Rivets projects.
  """

  defmacro __using__(_) do
    quote do
      @migrations_file ".migrations.exs"
      @index_file ".index.exs"
      @archive_file ".archive.exs"
    end
  end
end
