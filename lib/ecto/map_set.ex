defmodule Rivet.Ecto.MapSet do
  @moduledoc """
  Custom Type to support MapSet

  Contributor: Brandon Gillespie
  """
  @behaviour Ecto.Type

  @type t :: MapSet.t()

  def type, do: MapSet

  def cast(%MapSet{} = ms), do: ms
  def cast(list) when is_list(list), do: MapSet.new(list)
  def cast(_), do: :error

  def load(%MapSet{} = ms), do: ms
  def load(ms) when is_list(ms), do: {:ok, cast(ms)}
  def load(_), do: :error

  # only support virtual for now
  def dump(%MapSet{} = ms), do: {:ok, MapSet.to_list(ms)}
  def dump(_), do: :error

  def embed_as(_), do: :self
  def equal?(a, b), do: MapSet.equal?(a, b)
end
