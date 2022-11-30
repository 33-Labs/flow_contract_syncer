defmodule FlowContractSyncer.Repo do
  use Ecto.Repo,
    otp_app: :flow_contract_syncer,
    adapter: Ecto.Adapters.Postgres
end
