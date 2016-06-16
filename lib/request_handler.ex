defmodule RequestHandler do
  def handle(data) do
    # method stub
    case data do
      "ping" -> "pong"
      "ぬるぽ" -> "ガッ"
      "乒" -> "乓"
      "🍣" -> "🍕"
      "🍕" -> "🍣"
      x -> "You sent #{x} to the donuts TCP server\n"
    end
  end
end
