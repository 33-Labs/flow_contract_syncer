defmodule FlowContractSyncerWeb.SnippetView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("show.json", %{snippet: snippet}) do
    %{
      code: 0,
      data: render_one(snippet, __MODULE__, "snippet.json")
    }
  end

  def render("index.json", %{snippets: snippets}) do
    %{
      code: 0,
      data: render_many(snippets, __MODULE__, "snippet.json", as: :snippet)
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

  def render("contracts.json", %{contracts: contracts}) do
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
