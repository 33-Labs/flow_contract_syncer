defmodule FlowContractSyncerWeb.PageController do
  use FlowContractSyncerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
