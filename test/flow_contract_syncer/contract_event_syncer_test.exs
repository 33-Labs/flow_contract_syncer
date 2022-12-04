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
    assert events_count() == 3
  end

  defp events_count do
    ContractEvent
    |> Repo.all()
    |> Enum.count()
  end
end
