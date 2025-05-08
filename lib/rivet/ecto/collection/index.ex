defmodule Rivet.Ecto.Collection do
  @moduledoc """
  # For data models using Ecto. Options:

  `id_type: :uuid, :intid, :none` — how to handle record ID
  `features: [:short_id]` — enable/disable ShortId
  `required: [:field, ...]` — list of fields required for this model
  `update: [:field, ...]` — list of fields allowed to be updated on this model
  `create: [:field, ...]` — list of additional fields allowed only on creation.
                            unlike the other fields, whatever is provided is
                            concatenated to required and update. This defaults
                            to `[:id]`, so specify it as `[]` for no additional
                            create fields.
  `foreign_keys: [:field, ...]` - list of foreign key constraints (if any)
  `unique: [:field, ...]` — list of unique constraints (if any)

  recap:

  * `create:` ONLY on create, but is still optional (default: :id)
  * `required:` MUST exist on create, and at the intersection of required and update, those values must also exist
  * `update:` things that can be updated






  Note: fk and unique may also be tuple: {:key, [keyword-list options]}
  """

  import Ecto.Query, only: [from: 2]

  @callback validate(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  @callback build(params :: map()) :: Ecto.Changeset.t()
  @callback changeset(item :: map(), params :: map()) :: Ecto.Changeset.t()
  @callback change_prep(item :: map(), changes :: map()) :: {:ok, map()}
  @callback change_post(item :: map(), changes :: map()) :: map()
  @callback create_prep(item :: map(), changes :: map()) :: {:ok, map()}
  @callback create_post(item :: map(), changes :: map()) :: map()
  @callback delete(item :: map()) :: {:ok | :error, Ecto.Changeset.t() | map()}

  @optional_callbacks validate: 1,
                      build: 1,
                      changeset: 2,
                      change_prep: 2,
                      change_post: 2,
                      create_prep: 2,
                      create_post: 2,
                      delete: 1

  @doc """
  iex> enrich_query_args(%Ecto.Query{}, order_by: [asc: :asdf])
  #Ecto.Query<from q0 in query, order_by: [asc: q0.asdf]>
  iex> enrich_query_args(%Ecto.Query{}, desc: :asdf)
  #Ecto.Query<from q0 in query, order_by: [desc: q0.asdf]>
  iex> enrich_query_args(%Ecto.Query{}, asc: :asdf)
  #Ecto.Query<from q0 in query, order_by: [asc: q0.asdf]>
  iex> enrich_query_args(%Ecto.Query{}, limit: 10)
  #Ecto.Query<from q0 in query, limit: ^10>
  iex> enrich_query_args(%Ecto.Query{}, preload: [:narf])
  #Ecto.Query<from q0 in query, preload: [:narf]>
  iex> enrich_query_args(%Ecto.Query{}, select: [:narf])
  #Ecto.Query<from q0 in query, select: [:narf]>
  """
  def enrich_query_args(%Ecto.Query{} = query, args) do
    Enum.reduce(args, query, fn
      {:order_by, order_by}, query -> from(query, order_by: ^order_by)
      {:desc, key}, query -> from(query, order_by: [desc: ^key])
      {:asc, key}, query -> from(query, order_by: [asc: ^key])
      {:limit, limit}, query -> from(query, limit: ^limit)
      {:preload, preload}, query -> from(query, preload: ^preload)
      {:offset, offset}, query -> from(query, offset: ^offset)
      {:select, select}, query -> from(query, select: ^select)
      _, query -> query
    end)
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Rivet.Ecto.Collection.Context, opts
      use Rivet.Ecto.Collection.Model, opts
      use Rivet.Ecto.Collection.All, opts
      use Rivet.Ecto.Collection.Create, opts
      use Rivet.Ecto.Collection.Delete, opts
      use Rivet.Ecto.Collection.General, opts
      use Rivet.Ecto.Collection.One, opts
      use Rivet.Ecto.Collection.Stream, opts
      use Rivet.Ecto.Collection.Touch, opts
      use Rivet.Ecto.Collection.Update, opts
      use Rivet.Ecto.Collection.ShortId, opts
      use Rivet.Ecto.Collection.Summary, opts
    end
  end
end
