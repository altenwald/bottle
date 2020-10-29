# This is an example you can use for create your own templates
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.

[
  message: fn to_jid, type, payload ->
    "<message id='#{UUID.uuid4()}' to='#{to_jid}' type='#{type}'>#{payload}</message>"
  end
]
