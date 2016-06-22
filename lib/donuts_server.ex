require Logger
defmodule DonutsServer do
  def run do
    IO.puts "`mix run -e DonutsServer.run` will run this script "
  end

  @spec recv_callback(Connection.t, binary) :: :ok | {:error, term}
  defp recv_callback(conn, data) do
    data = data |> String.trim_trailing
    log(conn, "Received: #{data}")
    response = RequestHandler.handle(data)
    log(conn, "Response: #{response}")
    conn |> Connection.send(response)
  end

  @spec start_client_receiver(Connection.t) :: {:ok, pid}
  defp start_client_receiver(conn) do
    log(conn, "Connected from #{Connection.readable_client_addr conn}")
    conn |> Connection.send("Connection from #{Connection.readable_client_addr conn} established!\n")
    Connection.on_recv(conn, &recv_callback/2)
  end

  def tcp_server do
    {:ok, server} = Socket.TCP.listen 40000
    tcp_loop(server)
  end

  @spec tcp_loop(Socket.t) :: no_return
  defp tcp_loop(socket) do
    {:ok, client} = socket |> Socket.accept 
    conn=Connection.init(client)
    start_client_receiver(conn)
    log(conn, "Waiting next connection")

    tcp_loop(socket)
  end


  def udp_server do
    {:ok, socket} = Socket.UDP.open 40001
    udp_loop socket
  end
  @spec udp_loop(Socket.t) :: no_return
  defp udp_loop(socket) do
    {:ok, {data, client}} = socket |> Socket.Datagram.recv 
    conn=Connection.init({socket,client})
    recv_callback(conn,data)

    udp_loop socket
  end

  def websocket_server do
    {:ok, server} = Socket.Web.listen 40002
    websocket_loop server
  end
  @spec udp_loop(Socket.Web.t) :: no_return
  defp websocket_loop(socket) do
    client = socket |> Socket.Web.accept! # Got client connection request
    client |> Socket.Web.accept! # Accept client connection request
    conn=Connection.init(client) 
    start_client_receiver(conn)
    log(conn, "Waiting next connection")

    websocket_loop(socket)
  end

  @spec log(Connection.t, String.t, atom) :: any
  def log(conn, msg, level \\ :info) do
    msg_to_log = "[#{conn |> Map.get(:protocol) |> Atom.to_string |> String.upcase}] #{msg}"
    Logger.log(level,msg_to_log)
  end
end
