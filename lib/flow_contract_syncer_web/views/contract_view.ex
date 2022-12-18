defmodule FlowContractSyncerWeb.ContractView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  alias FlowContractSyncer.Schema.Contract

  def render("show.json", %{contract: contract}) do
    events = Contract.extract_events(contract)
    contract = Contract.with_deps_uuids(contract)

    %{
      code: 0,
      data: %{
        uuid: contract.uuid,
        address: contract.address,
        name: contract.name,
        code: contract.code,
        events: events,
        dependencies: contract.dependencies,
        dependants: contract.dependants
      }
    }
  end

  def render("index.json", %{contracts: contracts}) do
    %{
      code: 0,
      data:
        render_many(contracts, FlowContractSyncerWeb.PartialContractView, "partial_contract.json",
          as: :partial_contract
        )
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end
end
