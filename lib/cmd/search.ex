defmodule Cmd.Search do
  @moduledoc """
  This module provides the functionality for the `search` sub-command.
  """

  @doc """
  Searches the given project for previously indexed files (see `Indexing`) that
  match the given query. The search results are printed to the console.

  Note that the query input is first sent to OpenAI's API to generate an
  embedding to match against the vector store.
  """
  def run(opts, ai_module \\ AI) do
    opts
    |> Search.new(ai_module)
    |> Search.get_results()
    |> Enum.each(fn {file, score, data} ->
      if opts.detail do
        IO.puts("""
        -----
        # File: #{file} | Score: #{score}
        #{Map.get(data, "summary")}
        """)
      else
        IO.puts(file)
      end
    end)
  end
end
