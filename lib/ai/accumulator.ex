defmodule AI.Accumulator do
  @moduledoc """
  When file or other input to too large for the model's context window, this
  module may be used to process the file in chunks. It automatically modifies
  the supplied agent prompt to include instructions for accumulating a response
  across multiple chunks based on the `max_tokens` parameter supplied to the
  `get_response` function.
  """

  defstruct [
    :ai,
    :splitter,
    :buffer,
    :max_tokens,
    :model,
    :tools,
    :prompt,
    :question,
    :on_event
  ]

  @accumulator_prompt """
  You are processing input chunks in sequence.
  Each chunk is paired with an "accumulator" string to update, in the following format:
  ```
  # Question / Goal
  [user question or goal]

  # Accumulated Response
  [your accumulated response]
  -----
  [current input chunk]
  ```

  Guidelines for updating the accumulator:
  1. Add Relevant Content: Update the accumulator with your response to the current chunk
  2. Continuity: Build on the existing response, preserving its structure
  3. Handle Incompletes: If a chunk is incomplete, mark it (e.g., `<partial>`) to complete later
  4. Consistent Format: Append new content under "Accumulated Outline"

  Respond ONLY with the `Accumulated Response` section, including your updates from the current chunk, using the guidelines below.
  -----
  """

  @final_prompt """
  You have processed the user's input in chunks and collected your accumulated notes.
  Please review your notes and ensure that they are coherent and consistent.

  Your input will be in the format:
  ```
  # Question / Goal
  [user question or goal]

  # Accumulated Response
  [your accumulated response]
  ```

  Respond ONLY with your cleaned up `Accumulated Response` section, formatted per the guidelines below.
  -----
  """

  @spec get_response(AI.t(), keyword) :: {:ok, String.t()}
  def get_response(ai, opts \\ []) do
    with {:ok, max_tokens} <- Keyword.fetch(opts, :max_tokens),
         {:ok, model} <- Keyword.fetch(opts, :model),
         {:ok, prompt} <- Keyword.fetch(opts, :prompt),
         {:ok, input} <- Keyword.fetch(opts, :input),
         {:ok, question} <- Keyword.fetch(opts, :question) do
      tools = Keyword.get(opts, :tools, nil)
      on_event = Keyword.get(opts, :on_event, fn _, _ -> :ok end)

      %__MODULE__{
        ai: ai,
        splitter: AI.Splitter.new(input, max_tokens, model),
        buffer: "",
        max_tokens: max_tokens,
        model: model,
        tools: tools,
        prompt: prompt,
        question: question,
        on_event: on_event
      }
      |> reduce()
    end
  end

  defp reduce(%{splitter: %{done: true}} = acc) do
    finish(acc)
  end

  defp reduce(%{splitter: %{done: false}} = acc) do
    with {:ok, acc} <- process_chunk(acc) do
      reduce(acc)
    end
  end

  defp process_chunk(acc) do
    # Build the "user message" prompt, which contains the accumulated response.
    user_prompt = """
    # Question / Goal
    #{acc.question}

    # Accumulated Response
    #{acc.buffer}
    """

    # Get the next chunk from the splitter and update the splitter state. The
    # next chunk is based on the tokens remaining after factoring in the user
    # message size.
    {chunk, splitter} = AI.Splitter.next_chunk(acc.splitter, user_prompt)
    acc = %{acc | splitter: splitter}
    user_prompt = user_prompt <> chunk

    # The system prompt is the prompt for the chunk response, along with the
    # caller's agent instructions.
    system_prompt = """
    #{@accumulator_prompt}
    #{acc.prompt}
    """

    AI.Response.get(acc.ai,
      max_tokens: acc.max_tokens,
      model: acc.model,
      system: system_prompt,
      user: user_prompt,
      tools: acc.tools
    )
    |> then(fn {:ok, buffer, _usage} ->
      {:ok, %__MODULE__{acc | splitter: splitter, buffer: buffer}}
    end)
  end

  defp finish(acc) do
    user_prompt = """
    # Question / Goal
    #{acc.question}

    # Accumulated Response
    #{acc.buffer}
    """

    system_prompt = """
    #{@final_prompt}
    #{acc.prompt}
    """

    AI.Response.get(acc.ai,
      max_tokens: acc.max_tokens,
      model: acc.model,
      system: system_prompt,
      user: user_prompt
    )
    |> then(fn {:ok, response, _usage} ->
      {:ok, response}
    end)
  end
end
