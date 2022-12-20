defmodule FlowContractSyncer.SnippetParser do
  @moduledoc """
  Extract snippets from contract
  """

  use Task

  require Logger
  alias FlowContractSyncer.Repo

  alias FlowContractSyncer.Schema.{Contract, Network, Snippet}

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
      snippets = Snippet.extract_from_contract(contract)

      case insert_snippets_to_db(contract, snippets) do
        {:ok, _} ->
          Contract.to_snippet_parsed!(contract)

        error ->
          Logger.error(
            "[#{__MODULE__}] failed to parse snippets for contract: #{contract.id}. error: #{inspect(error)}"
          )

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
         %Contract{network_id: network_id, code_hash: contract_code_hash},
         snippets
       )
       when is_list(snippets) do
    Repo.transaction(fn ->
      snippets
      |> Enum.each(fn {code, type} ->
        # ignore the conflict
        %Snippet{}
        |> Snippet.changeset(%{
          network_id: network_id,
          contract_code_hash: contract_code_hash,
          code: code,
          type: type,
          status: :normal
        })
        |> Repo.insert!(on_conflict: :nothing)
      end)
    end)
  end
end
