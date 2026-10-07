defmodule Rivet.Ecto.MigrationHelpers do
  import Ecto.Migration

  @moduledoc """
  trigram:
    This is usually 3~5x the data size, so use carefully; don't use on "body" text

      create index(table, [keys], using: "GIN")

    Or truncate it: USING gin ((left(body, 500) ...

    Or vector it: USING gin ((to_tsvector('english', content) ...
    which also requires vectoring on search, where the 'X' and 'Y' are search params:

      WHERE to_tsvector('english', content) @@ to_tsquery('X & Y');

    And limit stuff in the index spec like:

      WHERE is_archived = false

  """

  defp from_fields(opts) do
    src = Keyword.get(opts, :fields, Keyword.get(opts, :from))
    {src, Keyword.get(opts, :to, src)}
  end

  def rename_fkey(from_table_name, to_table_name, opts \\ []) do
    {from_field, to_field} = from_fields(opts)

    from_fkey = build_identifier(from_table_name, from_field, :fkey)
    to_fkey = build_identifier(to_table_name, to_field, :fkey)

    rename_constraint(from_table_name, from_fkey, to_fkey)
  end

  def rename_pkey(from_table_name, to_table_name) do
    from_pkey = build_identifier(from_table_name, nil, :pkey)
    to_pkey = build_identifier(to_table_name, nil, :pkey)

    rename_constraint(from_table_name, from_pkey, to_pkey)
  end

  def rename_sequence(from_table_name, to_table_name, fields: fields) do
    from_seq = build_identifier(from_table_name, fields, :seq)
    to_seq = build_identifier(to_table_name, fields, :seq)

    execute(
      "ALTER SEQUENCE #{from_seq} RENAME TO #{to_seq};",
      "ALTER SEQUENCE #{to_seq} RENAME TO #{from_seq};"
    )
  end

  def rename_index(table_name, opts),
    do: rename_index(table_name, table_name, opts)

  def rename_index(from_table_name, to_table_name, opts) do
    {from_fields, to_fields} = from_fields(opts)

    from_index = build_identifier(from_table_name, from_fields, :index)
    to_index = build_identifier(to_table_name, to_fields, :index)

    execute(
      ~s[ALTER INDEX #{from_index} RENAME TO #{to_index};],
      ~s[ALTER INDEX #{to_index} RENAME TO #{from_index}]
    )
  end

  def rename_table(src, dst, opts \\ []) do
    rename_pkey(src, dst)

    Keyword.get(opts, :indexes, [])
    |> Enum.each(fn i ->
      rename_index(src, dst, fields: i)
    end)

    Keyword.get(opts, :fkeys, [])
    |> Enum.each(fn i ->
      rename_fkey(src, dst, fields: i)
    end)

    src_t = table(src)
    dst_t = table(dst)
    rename(src_t, to: dst_t)
  end

  def rename_constraint(table, from, to) do
    execute(
      ~s[ALTER TABLE #{table} RENAME CONSTRAINT "#{from}" TO "#{to}";],
      ~s[ALTER TABLE #{table} RENAME CONSTRAINT "#{to}" TO "#{from}";]
    )
  end

  @max_identifier_length 63
  def build_identifier(table_name, field_or_fields, ending) do
    ([table_name] ++ List.wrap(field_or_fields) ++ List.wrap(ending))
    |> Enum.join("_")
    |> String.slice(0, @max_identifier_length)
  end

  def to_id_atom(atom) when is_atom(atom) do
    Atom.to_string(atom)
    |> String.split("_")
    |> List.last()
    |> String.trim_trailing("s")
    |> Kernel.<>("_id")
    |> String.to_atom()
  end

  def uuid_ref(table, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:type, :uuid)
      |> Keyword.put_new(:on_delete, :delete_all)

    references(table, opts)
  end

  # to keep the macro simple, it only supports literals for the table name, not
  # variable inputs
  defmacro add_uuid_ref(table, opts \\ []) do
    null = Keyword.get(opts, :null, false)
    primary_key = Keyword.get(opts, :primary_key, false)
    key = Keyword.get(opts, :key, to_id_atom(table))

    opts =
      Keyword.drop(opts, [:null, :key, :primary_key])
      |> Keyword.put_new(:on_delete, :delete_all)

    quote do
      add(unquote(key), uuid_ref(unquote(table), unquote(opts)),
        null: unquote(null),
        primary_key: unquote(primary_key)
      )
    end
  end

  ##############################################################################
  # stargaze specific things

  ## while we have the agents table, in some cases we denormalize them for efficiency
  ## this keeps it all dry
  defmacro add_agent_refs do
    quote do
      add_uuid_ref(:users, null: true)
      add_uuid_ref(:orgs, null: true)
      add_uuid_ref(:projects, null: true)
    end
  end

  def create_agent_refs_limits(table, constraint, opts \\ []) do
    prefix = List.wrap(Keyword.get(opts, :prefix, []))
    suffix = List.wrap(Keyword.get(opts, :suffix, []))

    for key <- [:user_id, :org_id, :project_id] do
      create(unique_index(table, prefix ++ [key] ++ suffix, where: "#{key} IS NOT NULL"))
    end

    create_agent_ref_constraint(table, constraint)
  end

  defp ref_count_(op) do
    """
    ((user_id IS NOT NULL)::int +
     (org_id IS NOT NULL)::int +
     (project_id IS NOT NULL)::int) #{op}
    """
  end

  def create_agent_ref_constraint(table, :only_one),
    do: create(constraint(table, :exactly_one_agent_ref_id, check: ref_count_("= 1")))

  def create_agent_ref_constraint(table, :one_or_more),
    do: create(constraint(table, :at_least_one_agent_ref_id, check: ref_count_(">= 1")))

  def create_agent_ref_constraint(table, :none_or_one),
    do: create(constraint(table, :at_least_one_agent_ref_id, check: ref_count_("<= 1")))
end
