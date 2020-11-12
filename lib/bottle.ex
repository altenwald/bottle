defmodule Bottle do
  @moduledoc """
  Bottle is a Bot for XMPP designed to run a script based on Elixir
  scripting format (exs).

  The facilities Bottle gives to create scenarios
  """

  defp eval(file, bindings) do
    if File.exists?(file) do
      {output, _out_bindings} =
        File.read!(file)
        |> Code.eval_string(bindings)

      output
    else
      []
    end
  end

  def templates(domain) do
    eval("templates.exs", domain: domain)
  end

  def checks(domain) do
    eval("checks.exs", domain: domain)
  end

  def main(args) do
    opts = [
      switches: ["working-dir": :string, help: :boolean],
      aliases: [w: :"working-dir", h: :help]
    ]
    case OptionParser.parse(args, opts) do
      {switches, [file], []} ->
        if working_dir = switches[:"working-dir"] do
          File.cd!(working_dir)
        end
        Code.eval_file(file)
        :ok

      {[{:help, true} | _], [], []} ->
        help()

      _ ->
        IO.puts("Unknown parameters")
        help()
    end
  end

  defp help do
    IO.puts """
    Bottle v#{Application.spec(:bottle)[:vsn]}

    Syntax: bottle [-w <directory>] [-h] file.exs

    Parameters:
      -w | --working-dir <directory>  Changes the working directory.
      -h | --help                     Shows this message.
      file.exs                        File to be processed.
    """
  end
end
