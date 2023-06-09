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
    Logger.info("[#{__MODULE__}_#{name}] started")
    {:ok, pid} = Task.start_link(__MODULE__, :event_sync, [network])
    Process.register(pid, :"#{name}_#{id}_event_syncer")

    {:ok, pid}
  end

  def event_sync(%Network{} = network) do
    get_latest_height_res = client_impl().get_latest_block_height(network)

    sync_interval =
      case get_latest_height_res do
        {:ok, _} -> Network.contract_event_sync_interval(network) || @sync_interval
        _otherwise -> @timeout
      end

    case get_latest_height_res do
      {:ok, latest_height} ->
        synced_height = NetworkState.get_synced_height(network)
        min_height = network.min_sync_height

        start_height = max(synced_height, min_height)
        do_event_sync(network, start_height, latest_height)

      _otherwise ->
        nil
    end

    receive do
      :event_sync -> event_sync(network)
    after
      sync_interval -> event_sync(network)
    end
  end

  # What if end_height > latest_height?
  def do_event_sync(network, synced_height, latest_height)
      when synced_height < latest_height do
    chunk_size = Network.contract_event_sync_chunk_size(network) || @chunk_size

    start_height = synced_height + 1
    end_height = min(start_height + chunk_size, latest_height)

    with {:fetch, {:ok, events}} <- {:fetch, fetch_all_events(network, start_height, end_height)},
         {:save, {:ok, _ret}} <- {:save, save_events(network, events, end_height)} do
      do_event_sync(network, end_height, latest_height)
    else
      otherwise ->
        # If there is an error, we sleep and retry
        Logger.error("[#{__MODULE__}_#{network.name}] event fetch failed: #{inspect(otherwise)}")
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
      |> Enum.map(
        &Task.async(fn ->
          client_impl().get_events(network, &1, start_height, end_height)
        end)
      )
      |> Enum.map(&(Task.yield(&1, timeout) || Task.shutdown(&1, timeout)))

    all_fetched =
      Enum.all?(result, fn
        {:ok, {:ok, _}} -> true
        _otherwise -> false
      end)

    case all_fetched do
      true ->
        events =
          result
          |> Enum.flat_map(fn {:ok, {:ok, blocks}} ->
            blocks
            |> Enum.filter(fn
              %{"events" => _events} -> true
              _otherwise -> false
            end)
          end)
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
                          "block_timestamp" => raw_timestamp,
                          "events" => events
                        } ->
      {:ok, block_timestamp} = NaiveDateTime.from_iso8601(raw_timestamp)

      Enum.map(
        events,
        &(&1
          |> Map.put("block_height", String.to_integer(raw_height))
          |> Map.put("block_timestamp", block_timestamp))
      )
    end)
  end

  defp save_events(%Network{} = network, events, end_height) do
    Repo.transaction(fn ->
      events
      |> Enum.map(&ContractEvent.new(&1, network))
      |> Enum.filter(&(is_tuple(&1) and elem(&1, 0) == :ok))
      |> Enum.each(fn {:ok, changeset} ->
        Repo.insert!(changeset)
      end)

      {:ok, _} = NetworkState.update_height(network, end_height)
    end)
  end

  defp client_impl do
    Application.get_env(:flow_contract_syncer, :client) || Client
  end
end
