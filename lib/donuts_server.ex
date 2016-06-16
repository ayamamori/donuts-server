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
    Logger.info("Received: " <> data)
    :ok = socket |> Socket.Datagram.send("You sent #{data} to the donuts UDP server\n", client) 
    udp_loop socket
  end

  def tcp_server do
    {:ok, server} = Socket.TCP.listen 40000
    tcp_loop(server)
  end
  defp tcp_loop(socket) do
    client = socket |> Socket.accept!
    Logger.info("Connected")
    client |> Socket.Stream.send!("Connection established!\n")
    task = Task.async (fn -> tcp_client_loop(socket,client) end)
    Logger.info("Waiting next connection")

    tcp_loop(socket)
  end
  defp tcp_client_loop(socket,client) do
    data = client |> Socket.Stream.recv! 
    if is_nil(data) do
      client |> Socket.Stream.close
      Logger.info("Connection closed")
    else
      data = data |> String.rstrip(?\n) |> String.rstrip(?\r) |> String.rstrip(?\n)

      Logger.info("Received: " <> data)
      client |> Socket.Stream.send!("You sent #{data} to the donuts TCP server\n")
      tcp_client_loop(socket,client)
    end
  end
end
