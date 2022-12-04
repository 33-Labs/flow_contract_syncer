defmodule FlowContractSyncer.ClientBehaviour do
  alias FlowContractSyncer.Schema.Network

  @callback get_latest_block_height(network :: Network.t()) ::
              {:ok, integer()} | {:error, :get_height_failed}

  @callback get_events(
              network :: Network.t(),
              type :: String.t(),
              start_height :: integer(),
              end_height :: integer()
            ) :: {:ok, list()} | {:error, atom()} | {:resp_error, atom()}

  @callback execute_script(
              network :: Network.t(),
              encoded_script :: String.t(),
              encoded_arguments :: list(),
              opts :: Keyword.t()
            ) :: {:ok, any()} | {:error, atom()} | {:resp_error, atom()}
end
