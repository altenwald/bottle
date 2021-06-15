defmodule Bottle.CLI do
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

    "\n#{IO.ANSI.green()}" <>
    String.duplicate("*", max_line_len+6) <>
    lines_str <> "\n" <>
    String.duplicate("*", max_line_len+6) <>
    "\n#{IO.ANSI.reset()}"
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

  @spec add_boolean(map(), String.t(), String.t()) :: map()
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
    "#{IO.ANSI.yellow()}#{name}#{IO.ANSI.reset()}: "
  end

  @spec build_prompt(String.t(), Atom.t() | String.t()) :: String.t()
  def build_prompt(name, default) do
    "#{IO.ANSI.blue()}#{name}#{IO.ANSI.reset()} " <>
      "[#{IO.ANSI.green()}#{default}#{IO.ANSI.reset()}]> "
  end
end
