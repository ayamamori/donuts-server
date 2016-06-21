defmodule Connection do
  defstruct [:protocol, :client]

  @spec init(Port | {Socket.t, {Socket.Address.t, :inet.port_number}} | %Socket.Web{}) :: Connection
  def init(client) do
    case client do
      client when is_port(client) ->
        %Connection{protocol: :TCP, client: client}
      {socket, {ipaddr, port}} ->
        %Connection{protocol: :UDP, client: client}
      %Socket.Web{} ->
        %Connection{protocol: :Websocket, client: client}
    end
  end

  @spec send(Connection, any) :: :ok | {:error, term}
  def send(conn, payload) do
    case conn do
      %Connection{protocol: :TCP, client: client} ->
        client |> Socket.Stream.send(payload)
      %Connection{protocol: :UDP, client: {socket, client}} ->
        socket |> Socket.Datagram.send(payload, client) 
      %Connection{protocol: :Websocket, client: client} ->
        client |> Socket.Web.send({:text, payload})
    end
  end

  @spec onRecv(Connection, (... -> :ok)) :: :ok | {:close, atom} | :error
  def onRecv(conn, callback) do
    case conn do
      %Connection{protocol: :TCP} ->
        Task.start(fn -> onRecvTCPImpl(conn,callback)end)
      %Connection{protocol: :UDP} ->
        Task.start(fn -> onRecvUDPImpl(conn,callback)end)
      %Connection{protocol: :Websocket} ->
        Task.start(fn -> onRecvWebsocketImpl(conn,callback)end)
    end
  end

  defp onRecvTCPImpl(conn, callback) do
    {:ok, data} = conn |> Map.get(:client) |> Socket.Stream.recv
    if is_nil(data) do
      close(conn) #TODO: close should be implemented as a callback to be implemented by developer
      {:close, :ok}
    else
      apply(callback,[conn,data])
      onRecvTCPImpl(conn,callback)
    end
  end

  defp onRecvUDPImpl(conn, callback) do
    {client, socket} = (conn |> Map.get(:client))
    {:ok, {data, client}} = socket |> Socket.Datagram.recv 
    apply(callback,[conn,data])
    onRecvUDPImpl(conn,callback)
  end

  defp onRecvWebsocketImpl(conn, callback) do
    case conn |> Map.get(:client) |> Socket.Web.recv! do
      {:text, data} -> 
        apply(callback,[conn,data])
        onRecvWebsocketImpl(conn,callback)
      :close -> 
        close(conn)
        {:close, :ok}
      {:close, atom, binary} ->
        close(conn)
        {:close, atom}
    end 
  end

  def close(conn) do
    case conn do
      %Connection{protocol: :TCP, client: client} ->
        client |> Socket.Stream.close
      %Connection{protocol: :UDP, client: {socket, client}} ->
        :ok #nop
      %Connection{protocol: :Websocket, client: client} ->
        client |> Socket.Web.close 
    end
  end
end

