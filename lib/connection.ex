defmodule Connection do
  defstruct [:protocol, :client]

  @type t :: %Connection{
    protocol: atom, 
    client: Port | {Socket.t, {Socket.Address.t, :inet.port_number}} | %Socket.Web{}
  }

  @spec init(Port | {Socket.t, {Socket.Address.t, :inet.port_number}} | %Socket.Web{}) :: Connection.t
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

  @spec send(Connection.t, any) :: :ok | {:error, term}
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

  @doc """
  Start new process for receiving from client and callback server logic.
  For TCP, Websocket.
  """
  @spec on_recv(Connection.t, (... -> :ok)) :: {:ok, pid()} 
  def on_recv(conn, callback) do
    case conn do
      %Connection{protocol: :TCP} ->
        Task.start(fn -> on_recv_tcp_impl(conn,callback)end)
      %Connection{protocol: :Websocket} ->
        Task.start(fn -> on_recv_websocket_impl(conn,callback)end)
    end
  end

  @spec on_recv_tcp_impl(Connection.t, (... -> :ok)) :: {:close, atom} 
  defp on_recv_tcp_impl(conn, callback) do
    {:ok, data} = conn |> Map.get(:client) |> Socket.Stream.recv
    if is_nil(data) do
      close(conn) #TODO: close should be implemented as a callback to be implemented by developer
      DonutsServer.log(conn,"connection closed")
      {:close, :ok}
    else
      apply(callback,[conn,data])
      on_recv_tcp_impl(conn,callback)
    end
  end

  @spec on_recv_websocket_impl(Connection.t, (... -> :ok)) :: {:close, atom}
  defp on_recv_websocket_impl(conn, callback) do
    case conn |> Map.get(:client) |> Socket.Web.recv! do
      {:text, data} -> 
        apply(callback,[conn,data])
        on_recv_websocket_impl(conn,callback)
      :close -> 
        close(conn)#TODO: close should be implemented as a callback to be implemented by developer
        DonutsServer.log(conn,"connection closed")
        {:close, :ok}
      {:close, atom, binary} ->
        close(conn)#TODO: close should be implemented as a callback to be implemented by developer
        DonutsServer.log(conn,"connection closed")
        {:close, atom}
    end 
  end

  @spec readable_client_addr(Connection.t) :: String.t
  def readable_client_addr(conn) do
    {ipaddr, port} = client_addr(conn)
    (ipaddr |> Tuple.to_list |> Enum.join(".")) <> ":" <> Integer.to_string(port)
  end

  @spec client_addr(Connection.t) :: {Socket.Address.t, :inet.port_number}
  def client_addr(conn) do 
    case conn do
      %Connection{protocol: :TCP, client: client} ->
        case :inet.peername(client) do
          {:ok, {ipaddr, port}} -> 
            {ipaddr,port}
        end
      %Connection{protocol: :UDP, client: {socket, client}} ->
        client
      %Connection{protocol: :Websocket, client: client} ->
        case client |> Map.get(:socket) |> :inet.peername do
          {:ok, {ipaddr, port}} -> 
            {ipaddr, port}
        end
    end
  end

  @doc "For TCP, Websocket"
  @spec close(Connection.t) :: :ok | {:error, term}
  def close(conn) do
    case conn do
      %Connection{protocol: :TCP, client: client} ->
        client |> Socket.Stream.close
      #%Connection{protocol: :UDP, client: {socket, client}} ->
        #:ok #nop
      %Connection{protocol: :Websocket, client: client} ->
        client |> Socket.Web.close 
    end
  end
end

