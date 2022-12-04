defmodule FlowContractSyncer.ContractEventSyncerTest do
  use FlowContractSyncer.DataCase
  import FlowContractSyncer.ContractEventCase
  import Mox

  alias FlowContractSyncer.Schema.ContractEvent
  alias FlowContractSyncer.ContractEventSyncer

  setup :set_mox_global
  setup :create_network
  setup :generate_events

  @added_event "flow.AccountContractAdded"
  @updated_event "flow.AccountContractUpdated"
  @removed_event "flow.AccountContractRemoved"

  test "should sync contract events successfully", %{
    network: network, 
    added_events: added_events,
    updated_events: updated_events,
    removed_events: removed_events,
  } do
    FlowClientMock
    |> expect(:get_latest_block_height, 3, fn _network ->
      {:ok, 100}
    end)
    |> expect(:get_events, 3 * 10, fn _network, type, start_height, end_height ->
      filter = fn event, start_height, end_height ->
        height = String.to_integer(event["block_height"])
        height >= start_height and height <= end_height
      end

      case type do
        @added_event -> {:ok, added_events |> Enum.filter(& filter.(&1, start_height, end_height))}
        @updated_event -> {:ok, updated_events |> Enum.filter(& filter.(&1, start_height, end_height))}
        @removed_event -> {:ok, removed_events |> Enum.filter(& filter.(&1, start_height, end_height))}
      end
    end)

    {:ok, _} = ContractEventSyncer.start_link(network)
    Process.sleep(500)

    [event_0, event_1, event_2] = ContractEvent |> Repo.all()

    assert event_0.type == :added
    assert event_0.contract_name == "LUSD"
    assert event_0.address == "0x25ec8cce566c4ca7"
    assert event_0.block_height == 5
    assert event_0.tx_index == 0
    assert event_0.index == 1

    assert event_1.type == :updated
    assert event_1.contract_name == "LUSD"
    assert event_1.address == "0x25ec8cce566c4ca7"
    assert event_1.block_height == 15
    assert event_1.tx_index == 1
    assert event_1.index == 1

    assert event_2.type == :removed
    assert event_2.contract_name == "LUSD"
    assert event_2.address == "0x25ec8cce566c4ca7"
    assert event_2.block_height == 25
    assert event_2.tx_index == 2
    assert event_2.index == 1
  end
end
