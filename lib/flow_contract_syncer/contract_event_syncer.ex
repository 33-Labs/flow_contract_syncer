defmodule FlowContractSyncer.ContractEventSyncer do
  @moduledoc false

  use Task

  require Logger

  alias FlowContractSyncer.{Client, Repo}
  alias FlowContractSyncer.Schema.{ContractEvent, Network, NetworkState}

  # 100ms
  @sync_interval 100
  @chunk_size 250
  @timeout 5000
  @sleep_interval 1000

  @added_event "flow.AccountContractAdded"
  @updated_event "flow.AccountContractUpdated"
  @removed_event "flow.AccountContractRemoved"

  def start_link(%Network{name: name, id: id} = network) do
    {:ok, pid} = Task.start_link(__MODULE__, :event_sync, [network])
    Process.register(pid, :"#{name}_#{id}_event_syncer")

    {:ok, pid}
  end

  def event_sync(%Network{} = network) do
    {:ok, latest_height} = client_impl().get_latest_block_height(network)
    synced_height = NetworkState.get_synced_height(network)

    do_event_sync(network, synced_height, latest_height)

    sync_interval = Network.contract_event_sync_interval(network) || @sync_interval

    receive do
      :event_sync -> event_sync(network)
    after
      sync_interval -> event_sync(network)
    end
  end

  # What if end_height > latest_height?
  def do_event_sync(network, synced_height, latest_height)
    when synced_height < latest_height do
    chunk_size = Network.contract_event_chunk_size(network) || @chunk_size

    start_height = synced_height + 1
    end_height = min(start_height + chunk_size, latest_height)

    with {:fetch, {:ok, events}} <- {:fetch, fetch_all_events(network, start_height, end_height)},
      {:save, {:ok, _ret}} <- {:save, save_events(network, events, end_height)} do
      do_event_sync(network, end_height, latest_height)
    else
      _otherwise ->
        # If there is an error, we sleep and retry
        Process.sleep(@sleep_interval)
        do_event_sync(network, synced_height, latest_height)
    end
  end

  def do_event_sync(_network, synced_height, latest_height) 
    when synced_height >= latest_height do
    :ok     
  end

  defp fetch_all_events(network, start_height, end_height) do
    timeout = @timeout

    result = 
      [@added_event, @updated_event, @removed_event]
      |> Enum.map(& Task.async(fn ->
        client_impl().get_events(network, &1, start_height, end_height)
      end))
      |> Enum.map(& (Task.yield(&1, timeout) || Task.shutdown(&1, timeout)))

    all_fetched = Enum.all?(result, fn
      {:ok, {:ok, _}} -> true
      _otherwise -> false
    end)

    case all_fetched do
      true -> 
        events =
          result
          |> Enum.flat_map(fn {:ok, {:ok, blocks_with_events}} -> blocks_with_events end)
          |> extract_events()

        {:ok, events}
      false -> 
        {:error, :not_full_filled}
    end
  end

  defp extract_events(blocks_with_events) do
    blocks_with_events
    |> Enum.flat_map(fn %{
      "block_height" => raw_height, 
      "events" => events
    } ->
      Enum.map(events, & Map.put(&1, "block_height", String.to_integer(raw_height)))
    end)
  end

  defp save_events(%Network{} = network, events, end_height) do
    Repo.transaction(fn ->
      events
      |> Enum.map(& ContractEvent.new(&1, network))
      |> Enum.filter(& is_tuple(&1) and elem(&1, 0) == :ok)
      |> Enum.each(fn {:ok, changeset} ->
        Repo.insert!(changeset)
      end)

      NetworkState.update_height(network, end_height)
    end)
  end

  defp client_impl do
    Application.get_env(:flow_contract_syncer, :client) || Client
  end

end