defmodule Rivet.Test.RivetTest do
  use Rivet.Test.Case

  doctest Mix.Tasks.Rivet.List, import: true
  doctest Rivet.Ecto.Collection, import: true
  doctest Rivet.Graphql, import: true
  doctest Rivet.Migration, import: true
  doctest Rivet.Migration.Manage, import: true
  doctest Rivet.Loader, import: true
end
