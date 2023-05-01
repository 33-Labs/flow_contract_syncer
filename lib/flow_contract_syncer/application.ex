defmodule FlowContractSyncer.Application do
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

    if env() == :prod do
      start_enabled_networks()
    end

    token = FlowContractSyncerWeb.Plugs.ApiAuth.generate_token("lanford33")
    IO.inspect(token)

    ret
  end

  def start_enabled_networks do
    Network
    |> FlowContractSyncer.Repo.all()
    |> Enum.filter(& &1.is_enabled)
    |> Enum.map(fn network ->
      {:ok, _child} = start_contract_syncer_sup(network)
    end)
  end

  defp start_contract_syncer_sup(network) do
    Supervisor.start_child(
      FlowContractSyncer.Supervisor,
      child_spec(
        FlowContractSyncer.ContractSyncerSupervisor,
        [network],
        id: :"#{network.name}_sup"
      )
    )
  end

  def child_spec(mod, args, opts \\ []) do
    opts = opts |> Enum.into(%{})
    start = {mod, :start_link, args}
    %{start: start, id: mod} |> Map.merge(opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlowContractSyncerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp env do
    if function_exported?(Mix, :env, 0) do
      Mix.env()
    else
      case System.get_env("MIX_ENV") do
        "prod" -> :prod
        "test" -> :test
        _otherwise -> :dev
      end
    end
  end
end
