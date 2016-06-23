defmodule Connection do
  defstruct [:session_manager, :protocol, :client]

  @type t :: %Connection{
    protocol: atom, 
    client: Port | {Socket.t, {Socket.Address.t, :inet.port_number}} | %Socket.Web{}
  }

  @doc "For TCP and Websocket"
  @spec init(SessionManager.t, Port | {Socket.t, {Socket.Address.t, :inet.port_number}} | %Socket.Web{}) :: Connection.t
  def init(session_manager, client) do
    conn=case client do
      client when is_port(client) ->
        %Connection{session_manager: session_manager, protocol: :TCP, client: client}
      {socket, {ipaddr, port}} ->
        %Connection{session_manager: session_manager, protocol: :UDP, client: client}
      %Socket.Web{} ->
        %Connection{session_manager: session_manager, protocol: :Websocket, client: client}
    end
    SessionManager.add_session(conn)
    conn
  end

  """
  @doc "For UDP"
  @spec init_udp(Socket.t, {Socket.Address.t, :inet.port_number}) :: Connection.t
  def init_udp(socket,{ipaddr,port}) do 
    %Connection{session_manager: nil, protocol: :UDP, client: {socket, {ipaddr, port}}}
  end
  """

  @spec send_broadcast(Connection.t, any) :: :ok 
  def send_broadcast(conn , payload) do
    conn |> SessionManager.get_all |> Enum.each(fn conn -> Connection.send(conn, payload)end)
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
  @spec on_recv(Connection.t, (... -> :ok)) :: pid() 
  def on_recv(conn, callback) do
    case conn do
      %Connection{protocol: :TCP} ->
        {:ok, pid}=Task.start(fn -> on_recv_tcp_impl(conn,callback)end)
        pid
      %Connection{protocol: :Websocket} ->
        {:ok, pid}=Task.start(fn -> on_recv_websocket_impl(conn,callback)end)
        pid
    end
  end
  @spec on_recv_tcp_impl(Connection.t, (... -> :ok)) :: {:close, atom} 
  defp on_recv_tcp_impl(conn, callback) do
    {:ok, data} = conn |> Map.get(:client) |> Socket.Stream.recv
    if is_nil(data) do
      close(conn) #TODO: close should be implemented as a callback to be implemented by developer
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
        {:close, :ok}
      {:close, atom, binary} ->
        close(conn)#TODO: close should be implemented as a callback to be implemented by developer
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
    DonutsServer.log(conn,"connection closed")
    SessionManager.delete_session(conn)
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

