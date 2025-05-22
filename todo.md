bad migrations sometimes give bizarre errors and aren't handled correctly.

example:

      add(:parent_id, references(:server_attributes, on_delete: :cascade, type: :uuid),
        null: true
      )


in a migration caused a command error. The problem above is on_delete:cascade is wrong.

mix rivet new model {name} should work. problems:
- subfolders not done right; should handle 'Core.Db' but not make db_ prefix on tables and names.

we need this somewhere global :smile: I use the latter logic in guards all the time.

* make a default test for mapping tables that doesn't use '.id', and perhaps a
  --mapping flag or similar to note this
 migrate should print what its doing
* running 'mix rivet new model' prints 'creating' in _build folder even though it
  ends up in the right place, but this is odd. Also gets "model already exists..."
  error.

  Model already exists in `/.../src/_build/dev/lib/core/priv/rivet/migrations/migrations.exs`, not adding

  but it isn't in migrations.exs... so something is wrong

* adding new model isn't added to parent index
