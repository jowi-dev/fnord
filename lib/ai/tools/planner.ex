defmodule AI.Tools.Planner do
  @behaviour AI.Tools

  @impl AI.Tools
  def spec() do
    %{
      type: "function",
      function: %{
        name: "planner_tool",
        description: """
        The planner tool analyzes your progress thus far and makes
        recommendations on the next steps. Make heavy use of this tool to avoid
        rabbit holes and keep your research on track.
        """,
        parameters: %{
          type: "object",
          required: [],
          properties: %{}
        }
      }
    }
  end

  @impl AI.Tools
  def call(agent, _args) do
    label = "Examining findings and planning the next steps"
    status_id = Tui.add_step(label)

    agent
    |> AI.Agent.Planner.new()
    |> AI.Agent.Planner.get_suggestion()
    |> then(fn
      {:ok, suggestion} ->
        Tui.finish_step(status_id, :ok)
        {:ok, "[planner_tool]\n#{suggestion}"}

      {:error, reason} ->
        Tui.finish_step(status_id, :error, label, reason)
        {:error, reason}
    end)
  end
end
