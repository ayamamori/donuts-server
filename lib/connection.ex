defmodule Connection do
  defstruct [:protocol, :client]

  @spec init(Port | {Socket.Address.t, :inet.port_number} | %Socket.Web{}) :: Connection
  def init(client) do
    case client do
      client when is_port(client) ->
        %Connection{protocol: :TCP, client: client}
      {ipaddr, port} ->
        %Connection{protocol: :UDP, client: client}
      %Socket.Web{} ->
        %Connection{protocol: :Websocket, client: client}
    end
  end
end

