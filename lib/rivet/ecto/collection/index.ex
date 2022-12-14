defmodule Rivet.Ecto.Collection do
  @moduledoc """
  # For data models using Ecto. Options:

  `short_id: false` — enable/disable ShortId (not supported yet)
  `required: [:field, ...]` — list of fields required for this model
  `update: [:field, ...]` — list of fields allowed to be updated on this model
  `create: [:field, ...]` — list of additional fields allowed only on creation.
                            unlike the other fields, whatever is provided is
                            concatenated to required and update. This defaults
                            to `[:id]`, so specify it as `[]` for no additional
                            create fields.
  `foreign_keys: [:field, ...]` - list of foreign key constraints (if any)
  `unique: [:field, ...]` — list of unique constraints (if any)

  Note: fk and unique may also be tuple: {:key, [keyword-list options]}
  """

  import Ecto.Query, only: [from: 2]

  @callback validate(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  @callback build(params :: map()) :: Ecto.Changeset.t()
  @callback changeset(item :: map(), params :: map()) :: Ecto.Changeset.t()
  @callback change_prep(item :: map(), changes :: map()) :: Ecto.Changeset.t()
  @callback change_post(item :: map(), changes :: map()) :: Ecto.Changeset.t()
  @callback create_prep(item :: map(), changes :: map()) :: Ecto.Changeset.t()
  @callback create_post(item :: map(), changes :: map()) :: Ecto.Changeset.t()

  @optional_callbacks validate: 1,
                      build: 1,
                      changeset: 2,
                      change_prep: 2,
                      change_post: 2,
                      create_prep: 2,
                      create_post: 2

  def enrich_query_args(query, args) do
    Enum.reduce(args, query, fn
      {:order_by, order_by}, query -> from(query, order_by: ^order_by)
      {:desc, key}, query -> from(query, order_by: [desc: ^key])
      {:asc, key}, query -> from(query, order_by: [asc: ^key])
      {:limit, limit}, query -> from(query, limit: ^limit)
      {:preload, preload}, query -> from(query, preload: ^preload)
      {:select, select}, query -> from(query, select: ^select)
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
    end
  end
end
