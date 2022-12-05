defmodule FlowContractSyncerWeb.ContractSearchView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  alias FlowContractSyncer.Repo

  def render("contract_search.json", %{contracts: contracts})
      when is_list(contracts) do
    contracts = contracts |> Repo.preload([:dependants, :dependencies])

    %{
      code: 0,
      data:
        render_many(contracts, FlowContractSyncerWeb.ContractSearchView, "contract.json",
          as: :contract
        )
    }
  end

  def render("contract.json", %{contract: contract}) do
    %{
      uuid: contract.uuid,
      dependencies_count: contract.dependencies |> Enum.count(),
      dependants_count: contract.dependants |> Enum.count()
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end
end
