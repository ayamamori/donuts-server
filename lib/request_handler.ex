defmodule RequestHandler do
  def handle(data) do
    # method stub
    case data do
      "ping" -> "pong"
      "ぬるぽ" -> "ガッ"
      "乒" -> "乓"
      "🍣" -> "🍕"
      "🍕" -> "🍣"
      x -> 
      case MessagePack.unpack(x) do
        {:error, reason} -> "You sent #{x} to the donuts server\n"
        {:ok, msgpack} -> handle_msgpack(msgpack)
      end
    end
  end
  defp handle_msgpack(msgpack) do
    case msgpack do
      x when is_integer(x) -> MessagePack.pack!(x)
      "ping" -> MessagePack.pack!("pong")
      x -> MessagePack.pack!(["Some msgpack received, but couldn't be recognized", x])
    end
  end
end
