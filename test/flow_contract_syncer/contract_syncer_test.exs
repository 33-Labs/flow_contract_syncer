defmodule FlowContractSyncer.ContractSyncerTest do
  use FlowContractSyncer.DataCase
  import FlowContractSyncer.ContractEventCase
  import Mox

  alias FlowContractSyncer.Schema.{Contract, ContractEvent}

  alias FlowContractSyncer.{
    ContractSyncer
  }

  setup :set_mox_global
  setup :create_network
  setup :create_events

  test "should sync contracts successfully", %{
    network: network
  } do
    FlowClientMock
    |> expect(:execute_script, 3, fn _network, _script, _args, _opts ->
      {:ok,
       "eyJ0eXBlIjoiT3B0aW9uYWwiLCJ2YWx1ZSI6eyJ0eXBlIjoiQXJyYXkiLCJ2YWx1ZSI6W3sidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMifV19fQ=="}
    end)

    ContractSyncer.start_link(network)
    Process.sleep(500)

    [contract] = Contract |> Repo.all()
    assert contract.status == :removed
    assert contract.code == "\x03\x03"
    assert contract.parsed == false

    assert Enum.all?(ContractEvent |> Repo.all(), & &1.processed)
  end

  defp create_events(context) do
    network = context[:network]

    events = [
      %ContractEvent{
        network_id: network.id,
        digest: "2yiCYFtnllOJtCOjGRXqJI3hlqJAWHu5ZvMCq+N8LzM=",
        block_height: 25,
        tx_id: "441f1f480caf9bd1f693d753402193abae7327b778cf0291882b1c91a802be76",
        tx_index: 2,
        type: :removed,
        index: 1,
        address: "0x25ec8cce566c4ca7",
        code_hash: "ZQF2wq5qw69TwoTCtFpbw6dAw7xVw6HDmj9CFUDDpxVrwqVow7ZoOinCv2o=",
        contract_name: "LUSD",
        processed: false
      },
      %ContractEvent{
        network_id: network.id,
        digest: "3yiCYFtnllOJtCOjGRXqJI3hlqJAWHu5ZvMCq+N8LzM=",
        block_height: 15,
        tx_id: "441f1f480caf9bd1f693d753402193abae7327b778cf0291882b1c91a802be76",
        tx_index: 2,
        type: :added,
        index: 0,
        address: "0x25ec8cce566c4ca7",
        code_hash: "ZQF2wq5qw69TwoTCtFpbw6dAw7xVw6HDmj9CFUDDpxVrwqVow7ZoOinCv2o=",
        contract_name: "LUSD",
        processed: false
      },
      %ContractEvent{
        network_id: network.id,
        digest: "1yiCYFtnllOJtCOjGRXqJI3hlqJAWHu5ZvMCq+N8LzM=",
        block_height: 25,
        tx_id: "441f1f480caf9bd1f693d753402193abae7327b778cf0291882b1c91a802be76",
        tx_index: 2,
        type: :updated,
        index: 0,
        address: "0x25ec8cce566c4ca7",
        code_hash: "ZQF2wq5qw69TwoTCtFpbw6dAw7xVw6HDmj9CFUDDpxVrwqVow7ZoOinCv2o=",
        contract_name: "LUSD",
        processed: false
      }
    ]

    persisted_events = events |> Enum.map(&Repo.insert!(&1))

    [events: persisted_events]
  end
end
