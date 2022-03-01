defmodule Bottle.Config do
  @moduledoc """
  Read configuration files to create datasets and useful
  functions for handling these datasets.
  """

  @doc """
  Reads the configuration from a script Elixir file (exs) and returns
  the data as a map.
  """
  def read_file(file) do
    {%{} = data, _} = Code.eval_file(file)
    data
  end

  @doc """
  Create the JID from the dataset based on: user, domain and resource.
  """
  def get_jid(%{"user" => user, "domain" => domain, "resource" => res}) do
    Exampple.Xmpp.Jid.new(user, domain, res)
    |> to_string()
  end

  @doc """
  Create the bare JID from the dataset based on: user, domain and resource.
  """
  def get_bare_jid(dataset) do
    dataset
    |> get_jid()
    |> Exampple.Xmpp.Jid.to_bare()
  end
end
