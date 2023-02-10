defmodule FlowContractSyncerWeb.V2.ContractSearchView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("contract_search.json", %{count: count, contracts: contracts})
      when is_list(contracts) do
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

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end
end
