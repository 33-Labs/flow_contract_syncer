defmodule FlowContractSyncerWeb.ContractSearchView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("contract_search.json", %{contracts: contracts}) 
    when is_list(contracts) do
    %{
      status: "ok",
      result: contracts
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end
  
end