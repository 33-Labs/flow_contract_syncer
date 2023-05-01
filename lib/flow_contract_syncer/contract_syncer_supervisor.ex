defmodule FlowContractSyncer.ContractSyncerSupervisor do
  @moduledoc false

  use Supervisor

  require Logger

  alias FlowContractSyncer.{
    ContractEventSyncer,
    ContractSyncer,
    DependencyParser,
    SnippetParser
  }

  def start_link(network) do
    Logger.info("[#{__MODULE__}_#{network.name}] started")
    Supervisor.start_link(__MODULE__, network, name: :"#{network.name}_contract_syncer_sup")
  end

  def init(network) do
    children =
      case network.name do
        "mainnet" ->
          [
            {ContractEventSyncer, network},
            {ContractSyncer, network},
            {DependencyParser, network},
            {SnippetParser, network}
          ]

        _otherwise ->
          [
            {ContractEventSyncer, network},
            {ContractSyncer, network},
            {DependencyParser, network}
          ]
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
