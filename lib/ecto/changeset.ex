defmodule Rivet.Ecto.Changeset do
  @moduledoc """
  extensions for ecto change sets

  Contributor: Brandon Gillespie
  """
  import Ecto.Changeset, only: [validate_change: 4, get_change: 2, put_change: 3, add_error: 3]
  import Transmogrify.As

  # easier to just borrow from Ecto
  defp message(opts, key \\ :message, default) do
    Keyword.get(opts, key, default)
  end

  @doc """
  (replacement for validate_format, which supports negation)

  Validates a change has the given format.

  The format has to be expressed as a regular expression.

  ## Options

    * `:message` - the message on failure, defaults to "has invalid format"
    * `:not` - invert match for truth. default is false

  ## Examples

      validate_rex(changeset, :email, ~r/@/)
      validate_rex(changeset, :thing, ~r/[^a-z0-9]/, not: true)

  """
  #  @spec validate_rex(t, atom, Regex.t, Keyword.t) :: t
  def validate_rex(changeset, field, format, opts \\ []) do
    validate_change(changeset, field, {:rex, format, opts}, fn _, value ->
      match = value =~ format

      if opts[:not] do
        if !match,
          do: [],
          else: [{field, {message(opts, "has invalid format"), [validation: :format]}}]
      else
        if match,
          do: [],
          else: [{field, {message(opts, "has invalid format"), [validation: :format]}}]
      end
    end)
  end

  @doc """
  free-form updating, like a map
  """
  def validate_update(changeset, field, fun) do
    case fun.(get_change(changeset, field)) do
      :ok ->
        changeset

      {:replace, newval} ->
        put_change(changeset, field, newval)

      {:add, {newfield, newval}} ->
        put_change(changeset, newfield, newval)

      {:expand, vals} ->
        Enum.reduce(vals, changeset, fn [k, v], acc ->
          put_change(acc, k, v)
        end)

      {:error, msg} ->
        add_error(changeset, field, msg)
    end
  end

  @doc """
  If the key exists in the changeset, make sure it's a clean value
  """

  def validate_clean_atom(%{changes: changes} = chgset, key) do
    with {:ok, value} when is_binary(value) or is_atom(value) <- Map.fetch(changes, key) do
      put_change(chgset, key, as_key!(value))
    else
      _ -> chgset
    end
  end

  @doc """
  For a value that is a list of maps, validate each element with func
  """
  def validate_each(%{changes: changes} = chgset, key, func) do
    with {:ok, value} when is_list(value) <- Map.fetch(changes, key) do
      put_change(chgset, key, Enum.map(value, func))
    else
      _ -> chgset
    end
  end

  @doc """
  Convert keys map to atoms
  """
  def validate_map(%{changes: changes} = chgset, key) do
    with {:ok, value} when is_map(value) <- Map.fetch(changes, key) do
      put_change(chgset, key, Transmogrify.transmogrify(value))
    else
      _ -> chgset
    end
  end
end
