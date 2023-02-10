defmodule FlowContractSyncerWeb.V2.SnippetView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("index.json", %{count: count, snippets: snippets}) do
    %{
      code: 0,
      data: %{
        snippets: render_many(snippets, __MODULE__, "snippet.json", as: :snippet),
        total_snippets_count: count
      }
    }
  end

  def render("snippet.json", %{snippet: snippet}) do
    %{
      code_hash: snippet.code_hash,
      code: snippet.code,
      type: snippet.type,
      contracts_count: snippet.contracts_count
    }
  end

  def render("contracts.json", %{count: count, contracts: contracts}) do
    %{
      code: 0,
      data: %{
        contracts:
          render_many(
            contracts,
            FlowContractSyncerWeb.PartialContractView,
            "partial_contract.json",
            as: :partial_contract
          ),
        total_contracts_count: count
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
