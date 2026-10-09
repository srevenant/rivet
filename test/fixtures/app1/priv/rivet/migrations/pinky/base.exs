defmodule App1.Pinky.Base do
  use Ecto.Migration

  def change do
    create table(:pinky, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
    end
  end
end
