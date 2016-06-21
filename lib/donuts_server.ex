require Logger
defmodule DonutsServer do
  def run do
    IO.puts "`mix run -e DonutsServer.run` will run this script "
  end

  def tcp_server do
    {:ok, server} = Socket.TCP.listen 40000
    tcp_loop(server)
  end
  defp tcp_loop(socket) do
    {:ok, client} = socket |> Socket.accept 
    conn=Connection.init(client)
    log(conn, "Connected from #{Connection.readable_client_addr conn}")
    conn |> Connection.send "Connection from #{Connection.readable_client_addr conn} established!\n"
    Task.start (fn -> start_client_receiver(conn) end)
    log(conn, "Waiting next connection")

    tcp_loop(socket)
  end

  defp start_client_receiver(conn) do
    Connection.on_recv(conn, &recv_callback/2)
  end

  defp recv_callback(conn, data) do
    data = data |> String.rstrip(?\n) |> String.rstrip(?\r) |> String.rstrip(?\n)
    log(conn, "Received: #{data}")
    response = RequestHandler.handle(data)
    log(conn, "Response: #{response}")
    conn |> Connection.send(response)
  end

  def udp_server do
    {:ok, socket} = Socket.UDP.open 40001
    udp_loop socket
  end
  defp udp_loop(socket) do
    {:ok, {data, client}} = socket |> Socket.Datagram.recv 
    connection=Connection.init(client) |> IO.inspect
    data = data |> String.rstrip(?\n) |> String.rstrip(?\r) |> String.rstrip(?\n)
    log_udp("Received from #{udp_client_addr client}: " <> data)
    response = RequestHandler.handle(data)
    log_udp("To response #{udp_client_addr client}: " <> response)
    :ok = socket |> Socket.Datagram.send(response, client) 
    udp_loop socket
  end
  defp udp_client_addr(client) do
    {ipaddr, port} = client
    (ipaddr |> Tuple.to_list |> Enum.join(".")) <> ":" <> Integer.to_string(port)
  end

  def websocket_server do
    {:ok, server} = Socket.Web.listen 40002
    websocket_loop server
  end
  defp websocket_loop(socket) do
    client = socket |> Socket.Web.accept! # Got client connection request
    client |> Socket.Web.accept! # Accept client connection request
    connection=Connection.init(client) |> IO.inspect
    log_ws("Connected from #{websocket_client_addr client}")
    client |> Socket.Web.send!({:pong, "Connection from #{websocket_client_addr client} established!\n"})
    Task.start(fn -> websocket_client_loop(client) end)
    log_ws("Waiting next connection")

    websocket_loop(socket)
  end
  defp websocket_client_loop(client) do
    try do 
      case client |> Socket.Web.recv! do
        {:text, data} -> 
          log_ws("Received: " <> data)
          response = RequestHandler.handle(data)
          log_ws("To response: " <> response)
          client |> Socket.Web.send!({:text, response})
          websocket_client_loop(client)
        :close -> 
          log_ws("Connection closed.")
        {:close, atom, binary} ->
          log_ws("Connection closed: " <> Atom.to_string(atom))
      end
    rescue e ->
      a = client |> Socket.Web.close |> IO.inspect
      log_ws("Connection closed exceptionally")
      log_ws(Exception.format(:error, e))
    end

  end

  defp websocket_client_addr(client) do
    case client |> Map.get(:socket) |> :inet.peername do
    {:ok, {ipaddr, port}} -> 
      (ipaddr |> Tuple.to_list |> Enum.join(".")) <> ":" <> Integer.to_string(port)
    end
  end

  defp log_tcp(msg, level \\ :info) do
    log(msg, level, :tcp)
  end
  defp log_udp(msg, level \\ :info) do
    log(msg, level, :udp)
  end
  defp log_ws(msg, level \\ :info) do
    log(msg, level, :websocket)
  end
  def log(conn, msg, level \\ :info) do
    msg_to_log = "[#{conn |> Map.get(:protocol) |> Atom.to_string |> String.upcase}] #{msg}"
    Logger.log(level,msg_to_log)
  end
end
