defmodule FlowContractSyncer.ContractSyncerTest do
  use FlowContractSyncer.DataCase
  import FlowContractSyncer.ContractEventCase
  import Mox

  alias FlowContractSyncer.Schema.{
    Contract, 
    ContractEvent,
    ContractSnippet,
    Dependency,
    Network,
    Snippet
  }

  alias FlowContractSyncer.{
    ContractSyncer,
    DependencyParser,
    SnippetParser
  }

  setup :set_mox_global
  setup :create_network
  setup :create_dep_contract
  setup :create_events

  test "should sync contracts successfully", %{
    network: network,
    events: [removed_event, added_event, updated_event],
    dep: dep
  } do
    FlowClientMock
    |> expect(:execute_script, 1, fn _network, _script, _args, _opts ->
      {:ok, encoded_code()}
    end)
    |> expect(:execute_script, 2, fn _network, _script, _args, _opts ->
      {:ok, updated_encoded_code()}
    end)
    |> expect(:execute_script, 3, fn _network, _script, _args, _opts ->
      {:ok, updated_encoded_code()}
    end)

    config = %{ network.config | 
      "contract_sync_chunk_size" => 1,
      "deps_parse_interval" => 100,
      "snippets_parse_interval" => 100
    }

    network = network |> Network.changeset(%{config: config}) |> Repo.update!()

    {:ok, cs_pid} = ContractSyncer.start_link(network)
    DependencyParser.start_link(network)
    SnippetParser.start_link(network)

    Process.sleep(500)

    # == contract syncer ==

    contracts = Contract |> Repo.all()
    contract = contracts |> Enum.find(& &1.id != dep.id)
    assert contract.status == :normal
    assert contract.code == raw_code()
    assert contract.deps_parsed == true
    assert contract.snippet_parsed == true

    added_event = ContractEvent |> Repo.get(added_event.id)
    assert added_event.processed == true

    # == dependency parser ==

    [dep_relationship] = Dependency |> Repo.all()
    assert dep_relationship.contract_id == contract.id
    assert dep_relationship.dependency_id == dep.id

    # == snippet parser ==

    [snippet] = Snippet |> Repo.all()
    [contract_snippet] = ContractSnippet |> Repo.all()
    assert contract_snippet.contract_id == contract.id
    assert contract_snippet.snippet_id == snippet.id
    
    snippet_get = snippet.code |> String.replace([" ", "\n"], "")
    snippet_want = raw_snippet() |> String.replace([" ", "\n"], "")
    assert snippet_get == snippet_want

    # == round 2 ==

    # == contract syncer == 

    Process.send(cs_pid, :contract_sync, [])
    Process.sleep(500)

    contract = Contract |> Repo.get(contract.id)
    assert contract.status == :normal
    assert contract.code == updated_raw_code()

    updated_event = ContractEvent |> Repo.get(updated_event.id)
    assert updated_event.processed == true

    # == dependency parser ==

    assert Dependency |> Repo.all() |> Enum.count() == 0

    # == snippet parser ==

    # delete contract_snippet rather than snippet
    snippets = Snippet |> Repo.all()
    assert Enum.count(snippets) == 2
    snippet_2 = snippets |> Enum.find(& &1.id != snippet.id)

    [contract_snippet_2] = ContractSnippet |> Repo.all()
    assert contract_snippet.contract_id == contract.id
    assert contract_snippet_2.snippet_id == snippet_2.id
    
    snippet_get_2 = snippet_2.code |> String.replace([" ", "\n"], "")
    snippet_want_2 = raw_updated_snippet() |> String.replace([" ", "\n"], "")
    assert snippet_get_2 == snippet_want_2 

    # == round 3 ==

    # == contract syncer == 

    Process.send(cs_pid, :contract_sync, [])
    Process.sleep(500)

    contract = Contract |> Repo.get(contract.id)
    assert contract.status == :removed
    assert contract.code == updated_raw_code()

    removed_event = ContractEvent |> Repo.get(removed_event.id)
    assert removed_event.processed == true

    # == dependency parser ==

    assert Dependency |> Repo.all() |> Enum.count() == 0

    # == snippet parser ==

    # delete contract_snippet rather than snippet
    snippets = Snippet |> Repo.all()
    assert Enum.count(snippets) == 2

    [contract_snippet_3] = ContractSnippet |> Repo.all()
    # contract code is not changed, so contract_snippets will not change
    assert contract_snippet_3.id == contract_snippet_2.id
  end

  defp create_dep_contract(context) do
    network = context[:network]

    contract = %Contract{
      network_id: network.id,
      uuid: "A.33ec8cce566c4ca7.Dep",
      address: "0x33ec8cce566c4ca7",
      name: "Dep",
      status: :normal,
      code: "Nothing here",
      deps_parsed: true,
      snippet_parsed: true
    }
    |> Repo.insert!()

    [dep: contract]
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

  defp raw_snippet do
    """
    pub fun createEmptyResource(): @EmptyResource {
      return <- create EmptyResource()
    }
    """ 
  end

  defp raw_updated_snippet do
    """
    pub fun createEmptyResource(param: UInt64): @EmptyResource {
      return <- create EmptyResource()
    }
    """ 
  end

  defp raw_code do
    """
    import Dep from 0x33ec8cce566c4ca7

    pub contract RegexTester {
      // functions
      pub fun createEmptyResource(): @EmptyResource {
          return <- create EmptyResource()
      }

      init() {
      }
    }
    """
  end

  defp updated_raw_code do
    """
    pub contract RegexTester {
      // functions
      pub fun createEmptyResource(param: UInt64): @EmptyResource {
          return <- create EmptyResource()
      }

      init() {
      }
    }
    """
  end

  defp encoded_code do
    ~S(eyJ0eXBlIjoiT3B0aW9uYWwiLCJ2YWx1ZSI6eyJ0eXBlIjoiQXJyYXkiLCJ2YWx1ZSI6W3sidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTEyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTExIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwOSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMjAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNTEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNTEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjU2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1MiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5NyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1NSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk4In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5NyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiODIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijg0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIzIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQ3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQ3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTcifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTEwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTExIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTEyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNjkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjgyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTExIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiOTkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjU4In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjY0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjY5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwOSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEyMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI4MiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTcifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMjMifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNjAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNDUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiOTkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5NyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjY5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwOSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEyMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI4MiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTcifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0MCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0MSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMjUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEyMyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMjUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTI1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwIn1dfX0=)
  end

  defp updated_encoded_code do
    ~S(eyJ0eXBlIjoiT3B0aW9uYWwiLCJ2YWx1ZSI6eyJ0eXBlIjoiQXJyYXkiLCJ2YWx1ZSI6W3sidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk4In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5NyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiODIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijg0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIzIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQ3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQ3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTcifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTEwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTExIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTEyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNjkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjgyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTExIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiOTkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5NyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiOTcifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjU4In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijg1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjczIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNTgifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNjQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNjkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjgyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTExIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiOTkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEyMyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTcifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTE0In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2MCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0NSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI5OSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6Ijk3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNjkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA5In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjgyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTExIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExNyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiOTkifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjQxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEyNSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIzMiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTEwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwNSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMTYifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNDAifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiNDEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTIzIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjMyIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEyNSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMjUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTAifV19fQ==)
  end

end
