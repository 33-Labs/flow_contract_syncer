defmodule FlowContractSyncer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias FlowContractSyncer.Schema.Network

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      FlowContractSyncer.Repo,
      # Start the Telemetry supervisor
      FlowContractSyncerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: FlowContractSyncer.PubSub},
      # Start the Endpoint (http/https)
      FlowContractSyncerWeb.Endpoint,
      # Start a worker by calling: FlowContractSyncer.Worker.start_link(arg)
      # {FlowContractSyncer.Worker, arg}
      {Finch, name: MyFinch}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FlowContractSyncer.Supervisor]
    ret = {:ok, _pid} = Supervisor.start_link(children, opts)

    # Network
    # |> FlowContractSyncer.Repo.all()
    # |> Enum.filter(& &1.is_enabled)
    # |> Enum.map(fn network ->
    #   {:ok, child} = start_contract_syncer_sup(network)
    # end)

    ret
  end

  defp start_contract_syncer_sup(network) do
    Supervisor.start_child(
      FlowContractSyncer.Supervisor,
      {FlowContractSyncer.ContractSyncerSupervisor, network}
    )
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlowContractSyncerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
