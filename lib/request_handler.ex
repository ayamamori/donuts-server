defmodule RequestHandler do
  @spec handle(Connection.t, any) :: any
  def handle(conn,data) do
    # method stub
    sender=Connection.readable_client_addr(conn)
    case MessagePack.unpack(data) do
      {:error, reason} -> 
        case r(data) do
          :idk -> "#{sender} sent #{data} to the donuts server\n"
          {:ok, resp} -> "#{resp}\n"
        end
      {:ok, payload} -> handle_msgpack(payload)
    end
  end
  defp handle_msgpack(payload) do
    resp = case r(payload) do
      :idk -> ["Some msgpack received, but couldn't be recognized", payload]
      {:ok, resp} -> resp
    end 
    MessagePack.pack!(resp)
  end
  defp r(data) do
    case data do
      x when is_integer(x) -> {:ok, x}
      "ping" -> {:ok, "pong"}
      "ぬるぽ" -> {:ok, "ガッ"}
      "乒" -> {:ok, "乓"}
      "🍣" -> {:ok, "🍕"}
      "🍕" -> {:ok, "🍣"}
      x -> :idk
    end
  end
end
