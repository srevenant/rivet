defmodule Rivet.Seeds do
  @callback create(environment :: :dev | :test | :prod, tenant_id :: String.t()) :: :ok

  # defmacro __using__(_) do
  #   quote location: :keep do
  #   end
  # end

  # def configure() do
  #   {:ok, _} = Loader.Seeds.Tenant.upsert_seeds()
  #   Lib.Tenants.all!() |> configure
  # end
  #
  # def configure([%Lib.Tenant{id: id} | tenants]) do
  #   upsert_seeds(id)
  #   configure(tenants)
  # end
  #
  # def configure([tenant_id | tenants]) when is_binary(tenant_id) do
  #   upsert_seeds(tenant_id)
  #   configure(tenants)
  # end
  #
  # def configure(id) when is_binary(id), do: upsert_seeds(id)
  #
  # def configure([]), do: :ok
  #
  # def upsert_seeds(tenant_id) when is_binary(tenant_id) do
  #   :ok = Loader.Seeds.Auth.generate()
  #   :ok = Loader.Seeds.Config.upsert_seeds(tenant_id)
  #   Loader.Seeds.Data.load(tenant_id)
  # end
end
