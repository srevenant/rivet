defmodule TestApp.Repo do
  use Ecto.Repo, otp_app: :narf, adapter: Ecto.Adapters.Postgres
end
