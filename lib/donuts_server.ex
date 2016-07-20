require Logger
defmodule DonutsServer do
  def run do
    IO.puts "`mix run -e DonutsServer.run` will run this script "
  end

  @spec recv_callback(Connection.t, binary) :: :ok 
  defp recv_callback(conn, data) do
    data = data |> String.trim_trailing
    log(conn, "Received: #{data}")
    response = RequestHandler.handle(conn, data)
    log(conn, "Response: #{response}")
    conn |> Connection.send_broadcast(response)
  end

  @spec start_client_receiver(Connection.t) :: pid
  defp start_client_receiver(conn) do
    log(conn, "Connected from #{Connection.readable_client_addr conn}")
    #conn |> Connection.send("Connection from #{Connection.readable_client_addr conn} established!\n")
    Connection.on_recv(conn, &recv_callback/2)
  end

  def tcp_server do
    {:ok, server} = Socket.TCP.listen 40000
    session_manager=SessionManager.start_link
    tcp_loop(session_manager, server)
  end

  @spec tcp_loop(SessionManager.t, Socket.t) :: no_return
  defp tcp_loop(session_manager, socket) do
    {:ok, client} = socket |> Socket.accept 
    conn=Connection.init(session_manager, client)
    start_client_receiver(conn)
    log(conn, "Waiting next connection")

    tcp_loop(session_manager, socket)
  end


  def udp_server do
    {:ok, socket} = Socket.UDP.open 40001
    session_manager=SessionManager.start_link
    udp_loop(session_manager, socket)
  end
  @spec udp_loop(SessionManager.t, Socket.t) :: no_return
  defp udp_loop(session_manager, socket) do
    {:ok, {data, client}} = socket |> Socket.Datagram.recv 
    conn=Connection.init(session_manager, {socket,client})
    recv_callback(conn,data)

    udp_loop(session_manager, socket)
  end

  def websocket_server do
    {:ok, server} = Socket.Web.listen 40002
    session_manager=SessionManager.start_link
    websocket_loop(session_manager, server)
  end
  @spec websocket_loop(SessionManager.t, Socket.Web.t) :: no_return
  defp websocket_loop(session_manager, socket) do
    client = socket |> Socket.Web.accept! # Got client connection request
    client |> Socket.Web.accept! # Accept client connection request
    conn=Connection.init(session_manager, client) 
    start_client_receiver(conn)
    log(conn, "Waiting next connection")

    websocket_loop(session_manager, socket)
  end

  @spec log(Connection.t, String.t, atom) :: any
  def log(conn, msg, level \\ :info) do
    msg_to_log = "[#{conn |> Map.get(:protocol) |> Atom.to_string |> String.upcase}] #{msg}"
    Logger.log(level,msg_to_log)
  end
end
