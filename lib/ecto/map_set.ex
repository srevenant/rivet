defmodule Rivet.Ecto.MapSet do
  @moduledoc """
  Custom Type to support MapSet

  Contributor: Brandon Gillespie
  """
  @behaviour Ecto.Type

  @type t :: MapSet.t()

  def type, do: {:array, :string}

  def cast(%MapSet{} = set), do: {:ok, set}
  def cast(values) when is_list(values), do: {:ok, MapSet.new(values)}
  def cast(_), do: :error

  def load(values) when is_list(values), do: {:ok, MapSet.new(values)}
  def load(_), do: :error

  def dump(%MapSet{} = set), do: {:ok, MapSet.to_list(set)}
  def dump(_), do: :error

  def embed_as(_), do: :self

  def equal?(%MapSet{} = a, %MapSet{} = b), do: MapSet.equal?(a, b)
  def equal?(_, _), do: false
end
