defmodule RivetTestLib.Yoink.Migrations.Base do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:yoinks, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:object, :string)
      timestamps()
    end
  end
end
