defmodule Bottle do
  @moduledoc """
  Bottle is a Bot for XMPP designed to run a script based on Elixir
  scripting format (exs).

  The facilities Bottle gives to create scenarios
  """

  defmacro __using__(:checks) do
    quote do
      alias Exampple.Client
      alias Exampple.Router.Conn
      alias Exampple.Xml.Xmlel
    end
  end

  defmacro __using__(:scenario) do
    quote do
      import Bottle.Client
      import Exampple.Xml.Xmlel

      alias Bottle.CLI
      alias Exampple.Xmpp.Stanza
    end
  end

  defp eval(file, bindings) do
    if File.exists?(file) do
      {output, _out_bindings} =
        File.read!(file)
        |> Code.eval_string(bindings, file: file)

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
      switches: ["working-dir": :string, help: :boolean, "config-file": :string],
      aliases: [w: :"working-dir", h: :help, c: :"config-file"]
    ]
    case OptionParser.parse(args, opts) do
      {switches, [file], []} ->
        if config_file = switches[:"config-file"] do
          Config.Reader.read!(config_file)
          |> Application.put_all_env()
        end
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

    Syntax: bottle [-c <file>] [-w <directory>] [-h] file.exs

    Parameters:
      -c | --config-file              Sets the config file. Defaults to configs/config.exs
      -w | --working-dir <directory>  Changes the working directory.
      -h | --help                     Shows this message.
      file.exs                        File to be processed.
    """
  end
end
