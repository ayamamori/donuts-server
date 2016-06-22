defmodule Connection do
  defstruct [:session_manager, :protocol, :client]

  @type t :: %Connection{
    protocol: atom, 
    client: Port | {Socket.t, {Socket.Address.t, :inet.port_number}} | %Socket.Web{}
  }

  @doc "For TCP and Websocket"
  @spec init(SessionManager.t, Port | %Socket.Web{}) :: Connection.t
  def init(session_manager, client) do
    case client do
      client when is_port(client) ->
        %Connection{session_manager: session_manager, protocol: :TCP, client: client}
      %Socket.Web{} ->
        %Connection{session_manager: session_manager, protocol: :Websocket, client: client}
    end
  end

  @doc "For UDP"
  @spec init_udp(Socket.t, {Socket.Address.t, :inet.port_number}) :: Connection.t
  def init_udp(socket,{ipaddr,port}) do 
    %Connection{session_manager: nil, protocol: :UDP, client: {socket, {ipaddr, port}}}
  end

  @spec send_broadcast(Connection.t, any) :: :ok 
  def send_broadcast(%Connection{protocol: protocol, client: client, session_manager: session_manager}, payload) do
    case protocol do
      :UDP -> :ok #TODO
      other -> session_manager |> SessionManager.get_all |> Enum.each(fn pidconn -> Connection.send(elem(pidconn,1),payload)end)
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
  @spec on_recv(Connection.t, (... -> :ok)) :: pid()
  def on_recv(conn, callback) do
    case conn do
      %Connection{protocol: :TCP, session_manager: session_manager} ->
        {:ok, pid}=Task.start(fn -> on_recv_tcp_impl(conn,callback)end)
        SessionManager.add_session(session_manager,{pid,conn})
        pid
      %Connection{protocol: :Websocket, session_manager: session_manager} ->
        {:ok, pid}=Task.start(fn -> on_recv_websocket_impl(conn,callback)end)
        SessionManager.add_session(session_manager,{pid,conn})
        pid
    end
  end
  @spec on_recv_tcp_impl(Connection.t, (... -> :ok)) :: {:close, atom} 
  defp on_recv_tcp_impl(conn, callback) do
    {:ok, data} = conn |> Map.get(:client) |> Socket.Stream.recv
    if is_nil(data) do
      close(conn) #TODO: close should be implemented as a callback to be implemented by developer
      DonutsServer.log(conn,"connection closed")
      conn |> Map.get(:session_manager) |> SessionManager.delete_session(self)
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
        conn |> Map.get(:session_manager) |> SessionManager.delete_session(self)
        {:close, :ok}
      {:close, atom, binary} ->
        close(conn)#TODO: close should be implemented as a callback to be implemented by developer
        DonutsServer.log(conn,"connection closed")
        conn |> Map.get(:session_manager) |> SessionManager.delete_session(self)
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

