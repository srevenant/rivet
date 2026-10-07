defmodule Rivet.Utils.Criteria do
  @moduledoc """
  Criteria is used for cursor based pagination.

  Contributor: Brandon Gillespie
  """

  import Ecto.Query, only: [from: 2]

  @doc """
  Take out the :criteria item from the arguments
  Returns something like:
      {:ok, %{limit: 500, offset: 1, sort: {"taskTitle", :asc}}}
  """
  def take(options \\ [], fun \\ fn -> ordering_by(nil) end) do
    case List.keytake(options, :criteria, 0) do
      {{:criteria, criteria_arguments}, _} ->
        {:ok, parse_args(criteria_arguments, fun)}

      nil ->
        {:ok, parse_args(nil, fun)}
    end
  end

  defp parse_args(criteria_args, default_sort_function) do
    %{
      order: parse_order(criteria_args, default_sort_function),
      limit: parse_limit(criteria_args),
      offset: parse_offset(criteria_args)
    }
  end

  defp parse_order(%{sort: %{attribute: attribute, direction: direction}} = _criteria_args, _) do
    ordering_by({attribute, direction})
  end

  defp parse_order(_, default_sort_function), do: default_sort_function.()

  defp parse_limit(%{limit: limit} = _), do: limit
  defp parse_limit(_), do: 25

  defp parse_offset(%{offset: offset} = _), do: offset
  defp parse_offset(_), do: 0

  # Find out what field and what direction they want. i.e, last_name: :asc
  # This only finds the field and direction, it doesn't modify the query.
  defp ordering_by({field, direction} = _args) do
    sane_direction =
      case direction do
        :descending -> :desc
        _other -> :asc
      end

    sane_attr = Macro.underscore(field) |> String.to_existing_atom()
    {sane_attr, sane_direction}
  end

  # The default ordering by ID Ascending
  defp ordering_by(nil), do: {:id, :asc}

  @doc """
  Function to order the collection by attribute and direction
  """
  def order_by(%Ecto.Query{} = query, {attribute, dir}),
    do: from(t in query, order_by: [{^dir, ^attribute}])

  @doc """
  Function to apply the limit to the query (optional)
  """
  def limit(%Ecto.Query{} = query, limit), do: limit(query, true, limit)
  def limit(%Ecto.Query{} = query, false, _limit), do: query
  def limit(%Ecto.Query{} = query, _, limit), do: from(t in query, limit: ^limit)

  @doc """
  Function to apply the offset to the query (optional)
  """
  def offset(%Ecto.Query{} = query, offset), do: from(t in query, offset: ^offset)
  def offset(%Ecto.Query{} = query, false, _offset), do: query
  def offset(%Ecto.Query{} = query, _, offset), do: from(t in query, offset: ^offset)
end
