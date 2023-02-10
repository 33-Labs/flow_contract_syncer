defmodule FlowContractSyncerWeb.V2.SnippetSearchView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("snippet_search.json", %{count: count, snippets: snippets})
      when is_list(snippets) do
    %{
      code: 0,
      data: %{
        snippets:
          render_many(snippets, FlowContractSyncerWeb.SnippetView, "snippet.json", as: :snippet),
        total_snippets_count: count
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
