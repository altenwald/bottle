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
    "\n#{IO.ANSI.green()}" <>
    String.duplicate("*", 40) <>
    "\n** #{String.pad_trailing(msg, 34)} **\n" <>
    String.duplicate("*", 40) <>
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
  def ask_atom(prompt, default \\ "") do
    ask_string(prompt, default)
    |> String.to_atom()
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
