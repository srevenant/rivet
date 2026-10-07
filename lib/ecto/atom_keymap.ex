defmodule Rivet.Ecto.AtomKeymap do
  @moduledoc """
  Convert map keys from strings to atoms, recursively, when pulling in from the Db.

  Contributor: Brandon Gillespie
  """
  @behaviour Ecto.Type
  @type t :: map()

  def type, do: :map

  def dump(m), do: {:ok, m}

  def embed_as(_), do: :self

  def equal?(a, b), do: a == b

  def load(m), do: cast(m)

  ##############################################################################
  def cast(vars) when is_map(vars), do: {:ok, Transmogrify.transmogrify(vars, key_convert: :atom)}

  def cast(_), do: :error
end
