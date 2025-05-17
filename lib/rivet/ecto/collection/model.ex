defmodule Rivet.Ecto.Collection.Model do
  import Ecto.Changeset

  # coveralls-ignore-start
  @spec validate_foreign_keys(Ecto.Changeset.t(), [{term(), keyword()} | term()]) ::
          Ecto.Changeset.t()
  def validate_foreign_keys(chgset, [{key, opts} | rest]),
    do: foreign_key_constraint(chgset, key, opts) |> validate_foreign_keys(rest)

  def validate_foreign_keys(chgset, [key | rest]),
    do: foreign_key_constraint(chgset, key) |> validate_foreign_keys(rest)

  def validate_foreign_keys(chgset, []), do: chgset

  @spec validate_unique_constraints(Ecto.Changeset.t(), [{term(), keyword()} | term()]) ::
          Ecto.Changeset.t()
  def validate_unique_constraints(chgset, [{key, opts} | rest]),
    do: unique_constraint(chgset, key, opts) |> validate_unique_constraints(rest)

  def validate_unique_constraints(chgset, [key | rest]) do
    IO.inspect({key, chgset}, label: "unique_constraint")
    unique_constraint(chgset, key)
    |> IO.inspect(label: "AFTER")
    |> validate_unique_constraints(rest)
  end

  def validate_unique_constraints(chgset, []), do: chgset
  # coveralls-ignore-end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      import Rivet.Ecto.Collection.Model,
        only: [validate_foreign_keys: 2, validate_unique_constraints: 2]

      @required_fields Keyword.get(opts, :required, []) |> Enum.uniq()
      @update_allowed_fields Keyword.get(opts, :update, []) |> Enum.uniq()

      if @rivet_id_type == :none do
        @create_allowed_fields (Keyword.get(opts, :create, []) ++
                                  @required_fields ++ @update_allowed_fields)
                               |> Enum.uniq()
      else
        @create_allowed_fields (Keyword.get(opts, :create, [:id]) ++
                                  @required_fields ++ @update_allowed_fields)
                               |> Enum.uniq()
      end

      @foreign_keys Keyword.get(opts, :foreign_keys, []) |> Enum.uniq()
      @unique_constraints Keyword.get(opts, :unique, Keyword.get(opts, :unique_constraints, []))
                          |> Enum.uniq()

      if @rivet_debug do
        IO.inspect(
          [
            model: __MODULE__,
            required: @required_fields,
            update: @update_allowed_fields,
            create: @create_allowed_fields,
            foreign_keys: @foreign_keys,
            unique: @unique_constraints
          ],
          label: "Rivet.Ecto.Collection"
        )
      end

      def build(params \\ %{}) do
        %__MODULE__{}
        |> cast(params, @create_allowed_fields)
        |> create_validate()
        |> validate()
      end

      defoverridable build: 1

      def changeset(item, attrs) do
        item
        |> cast(attrs, @update_allowed_fields)
        |> change_validate()
        |> validate()
      end

      defoverridable changeset: 2

      @doc """
      create_validate is only run for creating new records
      """
      def create_validate(chgset), do: chgset
      defoverridable create_validate: 1

      @doc """
      change_validate is only run for changing existing records
      """
      def change_validate(chgset), do: chgset
      defoverridable change_validate: 1

      @doc """
      a hook if you just want to extend validate
      """
      def validate_post(chgset), do: chgset
      defoverridable validate_post: 1

      # default is to do nothing
      @doc """
      change_prep alters the params only, and may only return {:ok, params}
      """
      def change_prep(item, params), do: {:ok, params}
      defoverridable change_prep: 2

      @doc """
      change_post for side effects; should return the item

      Note: BE VERY CAREFUL on large impact effects. This can quickly become
      a performance bottleneck.
      """
      def change_post(item, params), do: item
      defoverridable change_post: 2

      @doc """
      create_prep alters the params only, and may only return {:ok, params}
      """
      def create_prep(item, params), do: {:ok, params}
      defoverridable create_prep: 2

      @doc """
      create_post for side effects; should return the item

      Note: BE VERY CAREFUL on large impact effects. This can quickly become
      a performance bottleneck.
      """
      def create_post(item, params), do: item
      defoverridable create_post: 2

      cond do
        @foreign_keys == [] and @unique_constraints == [] ->
          def validate(%Ecto.Changeset{} = chgset),
            do: validate_required(chgset, @required_fields) |> validate_post()

        @foreign_keys == [] ->
          def validate(%Ecto.Changeset{} = chgset) do
            IO.inspect(@unique_constraints, label: "UN?")
            chgset
            |> validate_required(@required_fields)
            |> validate_unique_constraints(@unique_constraints)
            |> validate_post()
          end

        @unique_constraints == [] ->
          def validate(%Ecto.Changeset{} = chgset) do
            chgset
            |> validate_required(@required_fields)
            |> validate_foreign_keys(@foreign_keys)
            |> validate_post()
          end

        true ->
          def validate(%Ecto.Changeset{} = chgset) do
            chgset
            |> validate_required(@required_fields)
            |> validate_foreign_keys(@foreign_keys)
            |> validate_unique_constraints(@unique_constraints)
            |> validate_post()
          end
      end

      defoverridable validate: 1
    end
  end
end
