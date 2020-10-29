defmodule Bottle do
  @moduledoc """
  Bottle is a Bot for XMPP designed to run a script based on Elixir
  scripting format (exs).

  The facilities Bottle gives to create scenarios
  """

  def templates(domain) do
    {output, _bindings} =
      File.read!("templates.exs")
      |> Code.eval_string([domain: domain])

    output
  end

  def main([]), do: IO.puts("help!")

  def main([file]) do
    Code.eval_file(file)
    :ok
  end
end
