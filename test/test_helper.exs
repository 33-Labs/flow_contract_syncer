Mox.defmock(FlowClientMock, for: FlowContractSyncer.ClientBehaviour)
Application.put_env(:flow_contract_syncer, :client, FlowClientMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(FlowContractSyncer.Repo, :manual)
