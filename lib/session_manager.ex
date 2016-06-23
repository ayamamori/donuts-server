defmodule SessionManager do
  defstruct [:agent]

  @type t :: %SessionManager{agent: pid}
  
  @spec start_link :: %SessionManager{}
  def start_link do
    {:ok, agent} = Agent.start_link(fn -> %{} end)
    %SessionManager{agent: agent}
  end

  @spec add_session(Connection.t) :: :ok
  def add_session(conn) do
    %Connection{client: client, session_manager: %SessionManager{agent: agent}} = conn
    Agent.update(agent, fn map -> Map.put(map, client, conn) end)
  end
  @spec delete_session(Connection.t) :: :ok
  def delete_session(conn) do
    %Connection{client: client, session_manager: %SessionManager{agent: agent}} = conn
    Agent.update(agent, fn map -> Map.delete(map, client) end)
  end

  @spec get_all(%SessionManager{}) :: [Connection.t]
  def get_all(%SessionManager{agent: agent}) do
    Agent.get(agent, fn map -> map end) |> Map.values
  end
end
