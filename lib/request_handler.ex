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
        {:ok, payload} -> handle_msgpack(payload)
      end
    end
  end
  defp handle_msgpack(payload) do
    resp = case payload do
      x when is_integer(x) -> x
      "乒" -> "乓"
      "ping" -> "pong"
      x -> ["Some msgpack received, but couldn't be recognized", x]
    end |> IO.inspect
    MessagePack.pack!(resp)
  end
end
