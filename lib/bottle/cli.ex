defmodule Bottle.CLI do
  @blue IO.ANSI.blue()
  @green IO.ANSI.green()
  @red IO.ANSI.red()
  @purple IO.ANSI.magenta()
  @yellow IO.ANSI.yellow()
  @reset IO.ANSI.reset()

  defmacro ifnil(value, do: block) do
    quote do
      value = unquote(value)

      if value do
        value
      else
        unquote(block)
      end
    end
  end

  @spec banner(String.t()) :: :ok
  def banner(msg) do
    {lines, max_line_len} =
      msg
      |> String.split(~r/[\r\n]+/)
      |> Enum.reduce({[], 40}, fn s, {lines, max_line_len} ->
        {[s | lines], max(max_line_len, String.length(s))}
      end)

    lines_str =
      lines
      |> Enum.reverse()
      |> Enum.map(&"\n** #{String.pad_trailing(&1, max_line_len)} **")
      |> Enum.join()

    "\n#{@green}" <>
    String.duplicate("*", max_line_len+6) <>
    lines_str <> "\n" <>
    String.duplicate("*", max_line_len+6) <>
    "\n#{@reset}"
    |> IO.puts()
  end

  @spec add_atom(map(), String.t()) :: map()
  def add_atom(data, name) do
    value =
      ifnil data[name] do
        name
        |> build_prompt()
        |> ask_atom()
      end

    Map.put(data, name, value)
  end

  @spec add_atom(map(), String.t(), Atom.t()) :: map()
  def add_atom(data, name, default) do
    value =
      ifnil data[name] do
        name
        |> build_prompt(default)
        |> ask_atom(default)
      end

    Map.put(data, name, value)
  end

  @spec add_boolean(map(), String.t()) :: map()
  def add_boolean(data, name) do
    value =
      ifnil data[name] do
        name
        |> build_prompt()
        |> ask_boolean()
      end

    Map.put(data, name, value)
  end

  @spec add_boolean(map(), String.t(), boolean()) :: map()
  def add_boolean(data, name, default) do
    value =
      ifnil data[name] do
        name
        |> build_prompt(if default, do: "Yn", else: "yN")
        |> ask_boolean(default)
      end

    Map.put(data, name, value)
  end

  @spec add_string(map(), String.t()) :: map()
  def add_string(data, name) do
    value =
      ifnil data[name] do
        name
        |> build_prompt()
        |> ask_string()
      end

    Map.put(data, name, value)
  end

  @spec add_string(map(), String.t(), String.t()) :: map()
  def add_string(data, name, default) do
    value =
      ifnil data[name] do
        name
        |> build_prompt(default)
        |> ask_string(default)
      end

    Map.put(data, name, value)
  end

  @spec ask_string(String.t(), String.t()) :: String.t()
  def ask_string(prompt, default \\ "") do
    prompt
    |> IO.gets()
    |> String.trim()
    |> case do
      "" -> default
      string -> string
    end
  end

  @spec ask_atom(String.t(), Atom.t()) :: Atom.t()
  def ask_atom(prompt, default \\ nil) do
    ask_string(prompt, to_string(default))
    |> String.to_atom()
  end

  @spec ask_boolean(String.t(), boolean()) :: boolean()
  def ask_boolean(prompt, default \\ true) do
    default = to_string(default)
    true_values = ["true", "t", "yes", "y", "on", "1"]
    String.downcase(ask_string(prompt, default)) in true_values
  end

  @spec build_prompt(String.t()) :: String.t()
  def build_prompt(name) do
    "#{@yellow}#{name}#{@reset}: "
  end

  @spec build_prompt(String.t(), Atom.t() | String.t()) :: String.t()
  def build_prompt(name, default) do
    "#{@blue}#{name}#{@reset} " <>
      "[#{@green}#{default}#{@reset}]> "
  end

  def print_stats_header do
    IO.puts("""
    +------+----------+----------+----------+----------+----------+----------+----------+----------+----------+
    | type | messages | presence |   iqs    |  total   | connectd | disconn. |  act.ok  | act.fail |    KB    |
    +------+----------+----------+----------+----------+----------+----------+----------+----------+----------+
    """ |> String.trim_trailing())
  end

  def print_stats_node(node) do
    print_stats_banner(to_string(node))
  end

  def print_stats_banner(banner) do
    IO.puts("| " <> String.pad_trailing(banner, 103) <> " |")
  end

  defp num(stat, color) do
    stat
    |> to_string()
    |> String.pad_leading(8)
    |> String.replace_prefix("", color)
    |> String.replace_suffix("", @reset)
  end

  defp kbytes(stat, color) do
    (stat / 1024)
    |> :erlang.float_to_binary(decimals: 2)
    |> String.split(".")
    |> then(fn [p1, p2] ->
      String.pad_leading(p1, 5) <> "." <> String.pad_trailing(p2, 2, "0")
    end)
    |> String.replace_prefix("", color)
    |> String.replace_suffix("", @reset)
  end

  def print_stats(stats) do
    data =
      "| #{@green}sent#{@reset} | " <>
        num(stats.message_sent, @green) <> " | " <>
        num(stats.presence_sent, @green) <> " | " <>
        num(stats.iq_sent, @green) <> " | " <>
        num(stats.total_sent, @green) <> " | " <>
        num(stats.connected, @purple) <> " | " <>
        num(stats.disconnected, @yellow) <> " | " <>
        num(stats.action_success, @green) <> " | " <>
        num(stats.action_failure, @red) <> " | " <>
        kbytes(stats.total_bytes_sent, @green) <> " |\n" <>
        "| #{@red}recv#{@reset} | " <>
        num(stats.message_recv, @red) <> " | " <>
        num(stats.presence_recv, @red) <> " | " <>
        num(stats.iq_recv, @red) <> " | " <>
        num(stats.total_recv, @red) <> " | " <>
        String.duplicate(" ", 8) <> " | " <>
        String.duplicate(" ", 8) <> " | " <>
        String.duplicate(" ", 8) <> " | " <>
        String.duplicate(" ", 8) <> " | " <>
        kbytes(stats.total_bytes_recv, @red) <> " |"

    IO.puts(data)
  end
end
