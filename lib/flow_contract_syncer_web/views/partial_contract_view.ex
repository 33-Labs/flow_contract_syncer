defmodule FlowContractSyncerWeb.PartialContractView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("partial_contracts.json", %{partial_contracts: contracts})
      when is_list(contracts) do
    %{
      code: 0,
      data: render_many(contracts, __MODULE__, "partial_contract.json", as: :partial_contract)
    }
  end

  def render("partial_contract.json", %{partial_contract: contract}) do
    %{
      uuid: contract.uuid,
      dependencies_count: contract.dependencies_count,
      dependants_count: contract.dependants_count
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end
end
