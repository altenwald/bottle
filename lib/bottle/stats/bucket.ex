defmodule Bottle.Stats.Bucket do
  @moduledoc """
  The stats are stored in buckets, it let us to concrete how much
  information was handled from time to time. The frequency of
  buckets is free and it could be decided aside.

  This module is handling everything regarding of the bucket, adding
  information and defining content mainly.
  """

  alias Exampple.Router.Conn

  defstruct connected: 0,
            connected_delta: 0,
            action_success: 0,
            action_success_delta: 0,
            action_failure: 0,
            action_failure_delta: 0,
            disconnected: 0,
            disconnected_delta: 0,
            message_sent: 0,
            message_sent_delta: 0,
            message_recv: 0,
            message_recv_delta: 0,
            iq_sent: 0,
            iq_sent_delta: 0,
            iq_recv: 0,
            iq_recv_delta: 0,
            presence_sent: 0,
            presence_sent_delta: 0,
            presence_recv: 0,
            presence_recv_delta: 0,
            total_bytes_sent: 0,
            total_bytes_sent_delta: 0,
            total_bytes_recv: 0,
            total_bytes_recv_delta: 0,
            total_sent: 0,
            total_sent_delta: 0,
            total_recv: 0,
            total_recv_delta: 0

  def new do
    %__MODULE__{}
  end

  def get(bucket) do
    %{
      timestamp: System.os_time(),
      action_success: bucket.action_success,
      action_failure: bucket.action_failure,
      connected: bucket.connected,
      disconnected: bucket.disconnected,
      message_sent: bucket.message_sent,
      message_recv: bucket.message_recv,
      iq_sent: bucket.iq_sent,
      iq_recv: bucket.iq_recv,
      presence_sent: bucket.presence_sent,
      presence_recv: bucket.presence_recv,
      total_sent: bucket.total_sent,
      total_recv: bucket.total_recv,
      total_bytes_sent: bucket.total_bytes_sent,
      total_bytes_recv: bucket.total_bytes_recv
    }
  end

  def get_deltas(bucket) do
    %{
      timestamp: System.os_time(),
      action_success: bucket.action_success_delta,
      action_failure: bucket.action_failure_delta,
      connected: bucket.connected_delta,
      disconnected: bucket.disconnected_delta,
      message_sent: bucket.message_sent_delta,
      message_recv: bucket.message_recv_delta,
      iq_sent: bucket.iq_sent_delta,
      iq_recv: bucket.iq_recv_delta,
      presence_sent: bucket.presence_sent_delta,
      presence_recv: bucket.presence_recv_delta,
      total_sent: bucket.total_sent_delta,
      total_recv: bucket.total_recv_delta,
      total_bytes_sent: bucket.total_bytes_sent_delta,
      total_bytes_recv: bucket.total_bytes_recv_delta
    }
  end

  def reset_deltas(%__MODULE__{} = bucket) do
    %__MODULE__{ bucket |
      connected_delta: 0,
      disconnected_delta: 0,
      action_success_delta: 0,
      action_failure_delta: 0,
      message_sent_delta: 0,
      message_recv_delta: 0,
      iq_sent_delta: 0,
      iq_recv_delta: 0,
      presence_sent_delta: 0,
      presence_recv_delta: 0,
      total_sent_delta: 0,
      total_recv_delta: 0,
      total_bytes_sent_delta: 0,
      total_bytes_recv_delta: 0
    }
  end

  def update(bucket, :action_success, _data) do
    %__MODULE__{bucket |
      action_success: bucket.action_success + 1,
      action_success_delta: bucket.action_success_delta + 1
    }
  end

  def update(bucket, :action_failure, _data) do
    %__MODULE__{bucket |
      action_failure: bucket.action_failure + 1,
      action_failure_delta: bucket.action_failure_delta + 1
    }
  end

  def update(bucket, :received, %Conn{stanza_type: "message", stanza: stanza}) do
    size =
      stanza
      |> to_string()
      |> byte_size()

    %__MODULE__{bucket |
      message_recv: bucket.message_recv + 1,
      total_recv: bucket.total_recv + 1,
      message_recv_delta: bucket.message_recv_delta + 1,
      total_recv_delta: bucket.total_recv_delta + 1,
      total_bytes_recv: bucket.total_bytes_recv + size,
      total_bytes_recv_delta: bucket.total_bytes_recv_delta + size
    }
  end

  def update(bucket, :received, %Conn{stanza_type: "iq", stanza: stanza}) do
    size =
      stanza
      |> to_string()
      |> byte_size()

    %__MODULE__{bucket |
      iq_recv: bucket.iq_recv + 1,
      total_recv: bucket.total_recv + 1,
      iq_recv_delta: bucket.iq_recv_delta + 1,
      total_recv_delta: bucket.total_recv_delta + 1,
      total_bytes_recv: bucket.total_bytes_recv + size,
      total_bytes_recv_delta: bucket.total_bytes_recv_delta + size
    }
  end

  def update(bucket, :received, %Conn{stanza_type: "presence", stanza: stanza}) do
    size =
      stanza
      |> to_string()
      |> byte_size()

    %__MODULE__{bucket |
      presence_recv: bucket.presence_recv + 1,
      total_recv: bucket.total_recv + 1,
      presence_recv_delta: bucket.presence_recv_delta + 1,
      total_recv_delta: bucket.total_recv_delta + 1,
      total_bytes_recv: bucket.total_bytes_recv + size,
      total_bytes_recv_delta: bucket.total_bytes_recv_delta + size
    }
  end

  def update(bucket, :sent, %Conn{stanza_type: "message", stanza: stanza}) do
    size =
      stanza
      |> to_string()
      |> byte_size()

    %__MODULE__{bucket |
      message_sent: bucket.message_sent + 1,
      total_sent: bucket.total_sent + 1,
      message_sent_delta: bucket.message_sent_delta + 1,
      total_sent_delta: bucket.total_sent_delta + 1,
      total_bytes_sent: bucket.total_bytes_sent + size,
      total_bytes_sent_delta: bucket.total_bytes_sent_delta + size
    }
  end

  def update(bucket, :sent, %Conn{stanza_type: "iq", stanza: stanza}) do
    size =
      stanza
      |> to_string()
      |> byte_size()

    %__MODULE__{bucket |
      iq_sent: bucket.iq_sent + 1,
      total_sent: bucket.total_sent + 1,
      iq_sent_delta: bucket.iq_sent_delta + 1,
      total_sent_delta: bucket.total_sent_delta + 1,
      total_bytes_sent: bucket.total_bytes_sent + size,
      total_bytes_sent_delta: bucket.total_bytes_sent_delta + size
    }
  end

  def update(bucket, :sent, %Conn{stanza_type: "presence", stanza: stanza}) do
    size =
      stanza
      |> to_string()
      |> byte_size()

    %__MODULE__{bucket |
      presence_sent: bucket.presence_sent + 1,
      total_sent: bucket.total_sent + 1,
      presence_sent_delta: bucket.presence_sent_delta + 1,
      total_sent_delta: bucket.total_sent_delta + 1,
      total_bytes_sent: bucket.total_bytes_sent + size,
      total_bytes_sent_delta: bucket.total_bytes_sent_delta + size
    }
  end

  def update(bucket, :connected, _event_data) do
    %__MODULE__{bucket |
      connected: bucket.connected + 1,
      connected_delta: bucket.connected_delta + 1
    }
  end

  def update(bucket, :disconnected, _event_data) do
    %__MODULE__{bucket |
      disconnected: bucket.disconnected + 1,
      disconnected_delta: bucket.disconnected_delta + 1
    }
  end

  def update(bucket, _event_name, _event_data) do
    bucket
  end
end
