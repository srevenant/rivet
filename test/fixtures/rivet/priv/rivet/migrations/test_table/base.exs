defmodule Rivet.Migrations.TestTable.Base do
  use Ecto.Migration

  def change do
    create table(:test_table, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      timestamps()
    end
  end
end
