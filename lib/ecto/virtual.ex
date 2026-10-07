defmodule Rivet.Ecto.Virtual do
  @moduledoc """
  Custom Type to support any virtual data.  Always serializes to nil, so when
  including it as a field add virtual: true.

  Contributor: Brandon Gillespie
  """
  @type t :: term()
  @behaviour Ecto.Type

  def type, do: :binary

  def embed_as(_), do: :self

  def cast(value), do: {:ok, value}

  def load(value), do: {:ok, value}

  def dump(_), do: {:ok, nil}

  def equal?(a, b), do: a == b
end
