defmodule FlowContractSyncerWeb.SnippetSearchView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("snippet_search.json", %{snippets: snippets})
      when is_list(snippets) do
    %{
      code: 0,
      data:
        render_many(snippets, FlowContractSyncerWeb.SnippetView, "snippet.json",
          as: :snippet
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
