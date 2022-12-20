defmodule FlowContractSyncer.SnippetParser do
  @moduledoc """
  Extract snippets from contract
  """

  use Task
  import Ecto.Query

  require Logger
  alias FlowContractSyncer.{Repo, Utils}

  alias FlowContractSyncer.Schema.{Contract, ContractSnippet, Network, Snippet}

  @interval 2000
  @chunk_size 100

  def start_link(%Network{name: name, id: id} = network) do
    Logger.info("[#{__MODULE__}_#{name}] started")
    {:ok, pid} = Task.start_link(__MODULE__, :parse_snippets, [network])
    Process.register(pid, :"#{name}_#{id}_snippet_parser")
    {:ok, pid}
  end

  def parse_snippets(%Network{} = network) do
    chunk_size = Network.snippets_parse_chunk_size(network) || @chunk_size

    Contract.snippet_unparsed(network, chunk_size)
    |> Enum.each(fn contract ->
      snippets = Contract.get_snippets(contract)

      case insert_snippets_to_db(contract, snippets) do
        {:ok, _} ->
          Contract.to_snippet_parsed!(contract)

        _error ->
          {:error, :parse_failed}
      end
    end)

    interval = Network.snippets_parse_interval(network) || @interval

    receive do
      :parse_snippets -> parse_snippets(network)
    after
      interval -> parse_snippets(network)
    end
  end

  defp insert_snippets_to_db(
         %Contract{id: contract_id, network_id: network_id},
         snippets
       )
       when is_list(snippets) do
    Repo.transaction(fn ->
      snippets
      |> Enum.each(fn {code, type} ->
        # ignore the conflict
        insert_or_update_snippet(code, type, network_id)
        |> case do
          {:ok, %{id: snippet_id}} ->
            case insert_or_update_contract_snippets(contract_id, snippet_id) do
              {:ok, _} ->
                :ok

              error ->
                Logger.error(
                  "[#{__MODULE__}] failed to insert contract snippet, error: #{inspect(error)}"
                )

                Repo.rollback(:insert_contract_snippets_failed)
            end

          error ->
            Logger.error("[#{__MODULE__}] failed to insert snippet, error: #{inspect(error)}")
            Repo.rollback(:insert_snippets_failed)
        end
      end)
    end)
  end

  defp insert_or_update_snippet(code, type, network_id) do
    code_hash = Utils.calc_code_hash(code)

    Snippet
    |> where(code_hash: ^code_hash, network_id: ^network_id)
    |> Repo.one()
    |> case do
      %Snippet{} = s -> s
      nil -> %Snippet{}
    end
    |> Snippet.changeset(%{
      network_id: network_id,
      code: code,
      type: type,
      status: :normal
    })
    |> Repo.insert_or_update()
  end

  defp insert_or_update_contract_snippets(contract_id, snippet_id) do
    ContractSnippet
    |> where(contract_id: ^contract_id, snippet_id: ^snippet_id)
    |> Repo.one()
    |> case do
      %ContractSnippet{} = cs -> cs
      nil -> %ContractSnippet{}
    end
    |> ContractSnippet.changeset(%{
      contract_id: contract_id,
      snippet_id: snippet_id
    })
    |> Repo.insert_or_update()
  end
end
