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
    log_tcp("Connected from #{tcp_client_addr client}")
    connection=Connection.init(client) |> IO.inspect
    connection |> Connection.send "Connection from #{tcp_client_addr client} established!\n"
    #client |> Socket.Stream.send("Connection from #{tcp_client_addr client} established!\n")
    Task.start (fn -> client_loop(connection) end)
    log_tcp("Waiting next connection")

    tcp_loop(socket)
  end

  defp client_loop(connection) do
    Connection.onRecv(connection, &callback/2)
  end

  defp callback(conn, data) do
    data = data |> String.rstrip(?\n) |> String.rstrip(?\r) |> String.rstrip(?\n)
    log("Received: #{data}", :info, conn |> Map.get(:protocol))
    response = RequestHandler.handle(data)
    log("Response: #{response}", :info, conn |> Map.get(:protocol))
    conn |> Connection.send(response)
  end

  defp tcp_client_loop(client) do
    try do
      data = client |> Socket.Stream.recv! 
      if is_nil(data) do
        client |> Socket.Stream.close
        log_tcp("Connection closed from client")
      else
        data = data |> String.rstrip(?\n) |> String.rstrip(?\r) |> String.rstrip(?\n)

        log_tcp("Received: " <> data)
        response = RequestHandler.handle(data)
        log_tcp("To response: " <> response)
        client |> Socket.Stream.send!(response)
        tcp_client_loop(client)
      end
    rescue e -> 
        client |> Socket.Stream.close
        log_tcp("Connection closed exceptionally")
        log_tcp(Exception.format(:error, e))
    end
  end

  defp tcp_client_addr(client) do
    case :inet.peername(client) do
    {:ok, {ipaddr, port}} -> 
      (ipaddr |> Tuple.to_list |> Enum.join(".")) <> ":" <> Integer.to_string(port)
    end
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
  defp log(msg, level, protocol \\ :none) do
    msg_to_log = "[#{protocol |> Atom.to_string |> String.upcase}] #{msg}"
    Logger.log(level,msg_to_log)
  end
end
