defmodule RequestHandler do
  @spec handle(Connection.t, any) :: any
  def handle(conn,data) do
    # method stub
    sender=Connection.readable_client_addr(conn)
    case data do
      "ping" -> "#{sender}: pong"
      "ぬるぽ" -> "#{sender}: ガッ"
      "乒" -> "#{sender}: 乓"
      "🍣" -> "#{sender}: 🍕"
      "🍕" -> "#{sender}: 🍣"
      x -> 
      case MessagePack.unpack(x) do
        {:error, reason} -> "#{sender} sent #{x} to the donuts server\n"
        {:ok, payload} -> "#{sender}: #{handle_msgpack(payload)}"
      end
    end
  end
  defp handle_msgpack(payload) do
    resp = case payload do
      x when is_integer(x) -> x
      "乒" -> "乓"
      "ping" -> "pong"
      x -> ["Some msgpack received, but couldn't be recognized", x]
    end 
    MessagePack.pack!(resp)
  end
end
