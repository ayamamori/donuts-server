defmodule SessionManager do
  defstruct [:agent]

  @type t :: %SessionManager{agent: pid}
  
  @spec start_link :: %SessionManager{}
  def start_link do
    {:ok, agent} = Agent.start_link(fn -> [] end)
    %SessionManager{agent: agent}
  end

  @spec add_session(%SessionManager{}, {pid, Connection.t}) :: :ok
  def add_session(%SessionManager{agent: agent}, session) do
    Agent.update(agent, fn list -> [session] ++list end)
  end
  @spec delete_session(%SessionManager{}, pid) :: :ok
  def delete_session(%SessionManager{agent: agent}, session) do
    Agent.update(agent, fn list -> List.keydelete(list, session ,0) end)
  end

  @spec get_all(%SessionManager{}) :: [{pid, Connection.t}]
  def get_all(%SessionManager{agent: agent}) do
    Agent.get(agent, fn list -> list end)
  end
end
