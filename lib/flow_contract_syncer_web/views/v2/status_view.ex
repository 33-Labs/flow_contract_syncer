defmodule FlowContractSyncerWeb.V2.StatusView do
  @moduledoc false

  use FlowContractSyncerWeb, :view

  def render("show.json", %{status: status}) do
    %{
      code: 0,
      data: status
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      message: message
    }
  end
end
