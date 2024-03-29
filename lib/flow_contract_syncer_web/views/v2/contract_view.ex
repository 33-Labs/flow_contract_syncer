defmodule FlowContractSyncerWeb.V2.ContractView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  alias FlowContractSyncer.Schema.Contract

  def render("show.json", %{contract: contract}) do
    events = Contract.extract_events(contract)
    dependants_count = Contract.dependants_count(contract)
    dependencies_count = Contract.dependencies_count(contract)

    %{
      code: 0,
      data: %{
        uuid: contract.uuid,
        address: contract.address,
        name: contract.name,
        code: contract.code,
        events: events,
        dependants_count: dependants_count,
        dependencies_count: dependencies_count
      }
    }
  end

  def render("index.json", %{count: count, contracts: contracts}) do
    %{
      code: 0,
      data: %{
        total_contracts_count: count,
        contracts:
          render_many(
            contracts,
            FlowContractSyncerWeb.PartialContractView,
            "partial_contract.json",
            as: :partial_contract
          )
      }
    }
  end

  def render("dependencies.json", %{
        uuid: uuid,
        dependencies: dependencies,
        dependencies_count: count
      })
      when is_binary(uuid) and is_list(dependencies) and is_integer(count) do
    %{
      code: 0,
      data: %{
        uuid: uuid,
        dependencies: dependencies,
        total_dependants_count: count
      }
    }
  end

  def render("dependants.json", %{
        uuid: uuid,
        dependants: dependants,
        dependants_count: count
      })
      when is_binary(uuid) and is_list(dependants) and is_integer(count) do
    %{
      code: 0,
      data: %{
        uuid: uuid,
        dependants: dependants,
        total_dependants_count: count
      }
    }
  end

  def render("snippets.json", %{snippets: snippets}) do
    %{
      code: 0,
      data: %{
        snippets:
          render_many(snippets, FlowContractSyncerWeb.SnippetView, "snippet.json", as: :snippet),
        total_snippets_count: Enum.count(snippets)
      }
    }
  end

  def render("deployments.json", %{deployments: deployments}) do
    %{
      code: 0,
      data: %{
        deployments: render_many(deployments, __MODULE__, "deployment.json", as: :deployment),
        total_deployments_count: Enum.count(deployments)
      }
    }
  end

  def render("deployment.json", %{deployment: deployment}) do
    %{
      tx_id: deployment.tx_id,
      block_height: deployment.block_height,
      block_timestamp: deployment.block_timestamp,
      type: deployment.type
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end
end
