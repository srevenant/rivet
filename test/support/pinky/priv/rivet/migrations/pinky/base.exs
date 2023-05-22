defmodule Pinky.Base do
  use Ecto.Migration

  def change do
    create table(:base, primary_key: false) do
      add(:id, :uuid, primary_key: true)
    end
  end
end
