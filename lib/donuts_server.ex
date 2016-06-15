require Logger
defmodule DonutsServer do
  def run do
    IO.puts "`mix run -e DonutsServer.run` will run this script "
  end

  def udp_server do
    {:ok, socket} = Socket.UDP.open 40001
    loop socket
  end
  def loop(socket) do
    {data, client} = socket |> Socket.Datagram.recv!
    Logger.info(data)
    socket |> Socket.Datagram.send(data, client) |> Logger.info
    loop socket
  end
end
