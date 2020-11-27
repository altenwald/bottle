# This is an example you can use for create your own templates
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.

[
  message: fn to_jid, type, payload ->
    "<message id='#{UUID.uuid4()}' to='#{to_jid}' type='#{type}'>#{payload}</message>"
  end,
  stream_mgmt_enable: fn ->
    "<enable xmlns='urn:xmpp:sm:3' resume='true' max='60'/>"
  end,
  stream_mgmt_resume: fn previd, h ->
    "<resume xmlns='urn:xmpp:sm:3' previd='#{previd}' h='#{h}'/>"
  end,
  stream_mgmt_a: fn h ->
    "<a xmlns='urn:xmpp:sm:3' h='#{h}'/>"
  end,
  stream_mgmt_r: fn ->
    "<r xmlns='urn:xmpp:sm:3'/>"
  end
]
