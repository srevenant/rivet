bad migrations sometimes give bizarre errors and aren't handled correctly.

example:

      add(:parent_id, references(:server_attributes, on_delete: :cascade, type: :uuid),
        null: true
      )


in a migration caused a command error. The problem above is on_delete:cascade is wrong.

