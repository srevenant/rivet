defmodule Rivet.Search.Pagination do
  @moduledoc """
  WIP - this describes the plans, not implementation.

  # Pagination notes

  Two pagination strategies:

    paginate: :simple   - (DEFAULT) Offset is used in combination with limit.
    paginate: :stateful - Uses a backend Db table.

  ## Simple Pagination

  Each query adds an 'offset' which comes from the user-args. This leaves paginating
  100% in the hands of the client, but is prone to issues as data changes between
  each query (records added/deleted/updated).

  Implementation:

    user_args has offset: x, along with limit: y. This is added to the query.

  ## Stateful Pagination

  Each search is given a unique ID (uuid). This RESETS if the filters change.

  A table in the DB caches the results that have been seen based on a search session

  ```elixir
      create table(:search_query, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:sig, :integer, null: false)
        timestamps()
      end

      create index(:search_query, [:updated_at])

      create table(:search_query_seen, primary_key: false) do
        add(:search_id,
            references(:search_query, type: :binary_id, on_delete: :delete_all),
            primary_key: true)
        add(:seen_id, :binary_id, primary_key: true)
      end
  ```

  ### Process:

  All of this runs in a transaction lock against SearchQuery to avoid duplicate
  searches on the same id (unlikely but still) {insert how??}

  1. lookup before each query checks the sig

  ```elixir
      # ... if other user_args change the result set, add them here too
      sig = :erlang.phash2({user.id, searcher, filters})
      from(q in SearchQuery, where: q.id == ^search_id and q.sig == ^sig) |> repo.exists?()
  ```

      if it doesn't exist, it can create it and get a new ID.

  2. Query; exclude against SearchQuerySeen in subquery:

  ```elixir
      seen_query =
        from(s in SearchQuerySeen,
          where:
            s.search_id == ^search_id and
              s.seen_id == field(parent_as(^binding), :id),
          select: 1
        )

      from(q in query, where: not exists(subquery(seen_query)))
  ```

  3. Insert the resulting IDs into the cache table...

     Two calls.
     One insert_all that adds seen_ids to SearchQuerySeen (handling collisions with replace)
     The second updates the SearchQuery table timestamp:

  ```elixir
      Repo.update_all(
        from(q in SearchQuery, where: q.id == ^search_id),
        set: [updated_at: DateTime.utc_now()]
      )
  ```

  4. Then cleanup is a scheduled job running every ~15m or so:

  ```elixir
    Repo.delete_all(from(q in SearchQuery, where: q.updated_at < ^cutoff))
  ```
  """
end
