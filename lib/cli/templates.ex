defmodule Rivet.Cli.Templates do
  # use Mix.Task
  import Mix.Generator

  ################################################################################
  def model(opts), do: model_template(opts)

  embed_template(:model, """
  defmodule <%= @c_mod %> do
    use TypedEctoSchema
    use Rivet.Ecto.Model

    typed_schema "<%= @c_table %>" do
      #belongs_to(:user, ..., type: :binary_id, foreign_key: :user_id)
      #field(:type, Enum)
      timestamps()
    end

    use Rivet.Ecto.Collection,
      required: [:user_id],
      update: [:user_id]
  end
  """)

  # coveralls-ignore-start
  ################################################################################
  def empty_list(opts), do: empty_list_template(opts)

  embed_template(:empty_list, """
  [
  ]
  """)

  ################################################################################
  def migrations(opts), do: migrations_template(opts)

  embed_template(:migrations, """
  alias <%= @c_mod %>.Migrations, as: M
  [
    [base: true, version: 0, module: M.Base]
  ]
  """)

  ################################################################################
  def migration(opts), do: migration_template(opts)

  embed_template(:migration, """
  defmodule <%= @c_mod %>.Migrations.<%= @c_name %> do
    @moduledoc false
    use Ecto.Migration

    def change do

    end
  end
  """)

  ################################################################################
  def base_migration(opts), do: base_migration_template(opts)

  embed_template(:base_migration, """
  defmodule <%= @c_mod %>.Migrations.Base do
    @moduledoc false
    use Ecto.Migration

    def change do
      create table(:<%= @c_table %>, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        # add(:user_id, references(:users, on_delete: :delete_all, type: :uuid))
        timestamps()
      end

      #create(index(:auth_accesses, [:domain, :ref_id]))
    end
  end
  """)

  ################################################################################
  def lib(opts), do: lib_template(opts)

  embed_template(:lib, """
  defmodule <%= @c_mod %>.Lib do
    use Rivet.Ecto.Collection.Context, model: <%= @c_mod %>
  end
  """)

  ################################################################################
  def empty(opts), do: empty_template(opts)

  embed_template(:empty, """
  defmodule <%= @c_mod %>.<%= @c_sub %> do
    @moduledoc false
  end
  """)

  ################################################################################
  def test(opts), do: test_template(opts)

  embed_template(:test, """
  defmodule <%= @c_base %>.Test.<%= @c_model %>Test do
    use <%= @c_base %>.Case, async: true

    doctest <%= @c_mod %>, import: true
    <%= if @lib do %>doctest <%= @c_mod %>.Lib, import: true
    <% end %><%= if @loader do %>doctest <%= @c_mod %>.Loader, import: true
    <% end %><%= if @seeds do %>doctest <%= @c_mod %>.Seeds, import: true
    <% end %><%= if @graphql do %>doctest <%= @c_mod %>.Graphql, import: true
    <% end %><%= if @resolver do %>doctest <%= @c_mod %>.Resolver, import: true
    <% end %><%= if @rest do %>doctest <%= @c_mod %>.Rest, import: true
    <% end %><%= if @cache do %>doctest <%= @c_mod %>.Cache, import: true
    <% end %>
    describe "factory" do
      test "factory creates a valid instance" do
        assert %{} = model = insert(:<%= @c_factory %>)
        assert model.id != nil
      end
    end

    describe "build/1" do
      test "build when valid" do
        params = params_with_assocs(:<%= @c_factory %>)
        assert %{valid?: true} = <%= @c_mod %>.build(params)
      end
    end

    describe "get/1" do
      test "loads saved transactions as expected" do
        c = insert(:<%= @c_factory %>)
        c_id = c.id
        assert %<%= @c_mod %>{id: ^c_id} = <%= @c_mod %>.one!(id: c.id)
      end
    end

    describe "create/1" do
      test "inserts a valid record" do
        attrs = params_with_assocs(:<%= @c_factory %>)
        assert {:ok, model} = <%= @c_mod %>.create(attrs)
        assert model.id != nil
      end
    end

    describe "delete/1" do
      test "deletes record" do
        model = insert(:<%= @c_factory %>)
        assert {:ok, deleted} = <%= @c_mod %>.delete(model)
        assert deleted.id == model.id
      end
    end
  end
  """)

  # coveralls-ignore-end
end
