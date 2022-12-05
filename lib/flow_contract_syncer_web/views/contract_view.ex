defmodule FlowContractSyncerWeb.ContractView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.Contract

  def render("show.json", %{contract: contract}) do
    contract =
      Repo.preload(contract, [
        :dependencies,
        :dependants
      ])

    %{
      code: 0,
      data: %{
        uuid: contract.uuid,
        address: contract.address,
        name: contract.name,
        code: contract.code,
        dependencies: get_dependencies_uuid(contract),
        dependants: get_dependants_uuid(contract)
      }
    }
  end

  def render("latest.json", %{contracts: contracts}) do
    contracts =
      Repo.preload(contracts, [
        :dependencies,
        :dependants
      ])

    %{
      code: 0,
      data:
        render_many(contracts, FlowContractSyncerWeb.ContractSearchView, "contract.json",
          as: :contract
        )
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end

  defp get_dependencies_uuid(%Contract{
         dependencies: deps
       })
       when is_list(deps) do
    deps |> Enum.map(& &1.uuid)
  end

  defp get_dependants_uuid(%Contract{
         dependants: dependants
       })
       when is_list(dependants) do
    dependants |> Enum.map(& &1.uuid)
  end
end
