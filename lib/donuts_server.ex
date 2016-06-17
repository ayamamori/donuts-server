require Logger
defmodule DonutsServer do
  def run do
    IO.puts "`mix run -e DonutsServer.run` will run this script "
  end

  def udp_server do
    {:ok, socket} = Socket.UDP.open 40001
    udp_loop socket
  end
  defp udp_loop(socket) do
    {:ok, {data, client}} = socket |> Socket.Datagram.recv 
    data = data |> String.rstrip(?\n) |> String.rstrip(?\r) |> String.rstrip(?\n)
    log_udp("Received from #{client_addr client}: " <> data)
    response = RequestHandler.handle(data)
    log_udp("To response #{client_addr client}: " <> response)
    :ok = socket |> Socket.Datagram.send(response, client) 
    udp_loop socket
  end

  def tcp_server do
    {:ok, server} = Socket.TCP.listen 40000
    tcp_loop(server)
  end
  defp tcp_loop(socket) do
    {:ok, client} = socket |> Socket.accept 

    log_tcp("Connected from #{client_addr client}")
    client |> Socket.Stream.send!("Connection from #{client_addr client} established!\n")
    Task.async (fn -> tcp_client_loop(client) end)
    log_tcp("Waiting next connection")

    tcp_loop(socket)
  end
  defp tcp_client_loop(client) do
    data = client |> Socket.Stream.recv! 
    if is_nil(data) do
      client |> Socket.Stream.close
      log_tcp("Connection closed")
    else
      data = data |> String.rstrip(?\n) |> String.rstrip(?\r) |> String.rstrip(?\n)

      log_tcp("Received: " <> data)
      response = RequestHandler.handle(data)
      log_tcp("To response: " <> response)
      client |> Socket.Stream.send!(response)
      tcp_client_loop(client)
    end
  end

  def websocket_server do
    {:ok, server} = Socket.Web.listen 40002
    websocket_loop server
  end
  defp websocket_loop(socket) do
    client = socket |> Socket.Web.accept! # Got client connection request
    log_ws("Connected from #{client_addr client}")
    client |> Socket.Web.accept! # Accept client connection request
    client |> Socket.Web.send!({:pong, "Connection from #{client_addr client} established!\n"})
    Task.async(fn -> websocket_client_loop(client) end)
    log_ws("Waiting next connection")

    websocket_loop(socket)
  end
  defp websocket_client_loop(client) do
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
  end

  defp client_addr(client) do
    {:ok, {ipaddr, port}} = :inet.peername(client)
    Enum.join(Tuple.to_list(ipaddr),".") <> ":"<> Integer.to_string(port)
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
    case level do
      :debug -> Logger.debug(msg_to_log)
      :info -> Logger.info(msg_to_log)
      :warn -> Logger.warn(msg_to_log)
      :error -> Logger.error(msg_to_log)
    end
  end
end
