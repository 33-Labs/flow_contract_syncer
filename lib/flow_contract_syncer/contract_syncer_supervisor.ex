defmodule FlowContractSyncer.ContractSyncerSupervisor do
  @moduledoc false

  use Supervisor

  require Logger

  alias FlowContractSyncer.{
    ContractEventSyncer,
    ContractSyncer,
    DependencyParser
  }

  def start_link(network) do
    Logger.info("[#{__MODULE__}_#{network.name}] started")
    Supervisor.start_link(__MODULE__, network, name: :"#{network.name}_contract_syncer_sup")
  end

  def init(network) do
    children = [
      {ContractEventSyncer, network},
      {ContractSyncer, network},
      {DependencyParser, network}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
