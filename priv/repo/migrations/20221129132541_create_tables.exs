defmodule FlowContractSyncer.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table("networks") do
      add :name, :string, null: false
      add :endpoint, :string, null: false
      add :min_sync_height, :bigint, null: false
      add :is_enabled, :boolean, null: false, default: false
      add :config, :map, null: false, default: %{}
    end

    create unique_index("networks", [:name], name: :networks_name_index)

    create table("network_states") do
      add :network_id, :bigint, null: false
      add :synced_height, :bigint, null: false, default: 0

      timestamps()
    end

    create unique_index("network_states", [:network_id], name: :network_states_network_id_index)

    create table("contract_events") do
      add :network_id, :bigint, null: false
      # used as uuid
      add :digest, :string, null: false
      add :block_height, :bigint, null: false
      add :block_timestamp, :naive_datetime_usec, null: false
      add :tx_id, :string, null: false
      add :tx_index, :integer, null: false

      # 0: flow.AccountContractAdded
      # 1: flow.AccountContractUpdated
      # 2: flow.AccountContractRemoved
      add :type, :integer, null: false
      # event_index
      add :index, :integer, null: false
      add :address, :string, null: false
      add :code_hash, :string, null: false
      add :contract_name, :string, null: false

      add :processed, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index("contract_events", [:network_id, :digest],
             name: :events_network_id_digest_index
           )

    create index("contract_events", [:network_id, :address, :contract_name])
    create index("contract_events", [:network_id, :processed])
    create index("contract_events", [:network_id, :block_height])

    create table("contracts") do
      add :network_id, :bigint, null: false
      add :uuid, :string, null: false
      add :address, :string, null: false
      add :name, :string, null: false

      # 0: normal
      # 1: removed
      add :status, :integer, null: false
      add :code, :text
      # sha2_256 of code
      add :code_hash, :string

      # dependency parsed
      add :deps_parsed, :boolean, null: false, default: false
      add :snippet_parsed, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index("contracts", [:network_id, :uuid], name: :contracts_network_id_uuid_index)
    create index("contracts", [:network_id, :address])
    create index("contracts", [:network_id, :name])
    create index("contracts", [:network_id, :deps_parsed])
    create index("contracts", [:network_id, :snippet_parsed])
    create index("contracts", [:network_id, :code_hash])

    create table("dependencies") do
      add :contract_id, :bigint, null: false
      add :dependency_id, :bigint, null: false

      timestamps()
    end

    create index("dependencies", [:contract_id])
    create index("dependencies", [:dependency_id])

    create unique_index(
             "dependencies",
             [:contract_id, :dependency_id],
             name: :dependencies_contract_id_dependency_id_index
           )

    create unique_index(
             "dependencies",
             [:dependency_id, :contract_id],
             name: :dependencies_dependency_id_contract_id_index
           )

    create table("snippets") do
      add :network_id, :bigint, null: false

      add :code_hash, :string, null: false
      add :code, :text

      # resource
      # struct
      # resource_interface
      # struct_interface
      # function
      # enum
      # event
      add :type, :integer, null: false

      # normal
      # removed
      add :status, :integer, null: false

      timestamps()
    end

    create unique_index("snippets", [:code_hash, :network_id],
             name: :snippets_code_hash_network_id_index
           )

    create index("snippets", [:network_id, :status])
    create index("snippets", [:network_id, :type])

    create table("contract_snippets") do
      add :contract_id, :bigint, null: false
      add :snippet_id, :bigint, null: false

      timestamps()
    end

    create index("contract_snippets", [:contract_id])
    create index("contract_snippets", [:snippet_id])

    create unique_index(
             "contract_snippets",
             [:contract_id, :snippet_id],
             name: :contract_snippets_contract_id_snippet_id_index
           )

    create unique_index(
             "contract_snippets",
             [:snippet_id, :contract_id],
             name: :contract_snippets_snippet_id_contract_id_index
           )
  end
end
