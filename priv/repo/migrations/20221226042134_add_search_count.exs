defmodule FlowContractSyncer.Repo.Migrations.AddSearchCount do
  use Ecto.Migration

  def change do
    alter table("network_states") do
      add :contract_search_count, :bigint, default: 0
      add :snippet_search_count, :bigint, default: 0
    end
  end
end
