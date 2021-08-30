# This is an example you can use for create your own bots
# to be in use with bottle.

use Bottle, :bot

bot :romeo do
  set user: "romeo"
  set pass: "secret1"
  set domain: "shakespeare.im"
  set host: "localhost"

  set tls: "no"
  set stream_mgmt: "disable"
  set resource: "montesco"

  login()
  wait_for :julieta

  run for: {:times, 100}, as: :ordered do
    step :sending do
      sending :message, to: :julieta, body: "Oh! Julieta!"
      checking :receipt, from: :julieta
      checking :received, from: :julieta
      checking :displayed, from: :julieta
    end

    step :receiving do
      checking :message, from: :julieta
      sending :received, to: :julieta
      sending :displayed, to: :julieta
    end

    maybe :from_mercutio do
      checking :message, from: :mercutio
      sending :received, to: :mercutio
    end

    wait 1_000
  end

  logout()
end

bot :julieta do
  set user: "julieta"
  set pass: "secret2"
  set domain: "shakespeare.im"
  set host: "localhost"

  set tls: "no"
  set stream_mgmt: "disable"
  set resource: "capuleto"

  login()
  wait_for :romeo

  run for: {:times, 100}, as: :ordered do
    step :receiving do
      checking :message, from: :romeo
      sending :received, to: :romeo
      sending :displayed, to: :romeo
    end

    step :sending do
      sending :message, to: :romeo, body: "Oh! Romeo!"
      checking :receipt
      checking :received
      checking :displayed
    end

    wait 1_000
  end

  logout()
end

bot :mercutio do
  set user: "mercutio"
  set pass: "secret3"
  set domain: "shakespeare.im"
  set host: "localhost"

  set tls: "no"
  set stream_mgmt: "disable"
  set resource: "friend"

  set chaotic_delay: 100..1000
  set chaotic_running: 1..3

  login()
  wait_for :romeo

  run for: {:times, 15}, as: :chaotic do
    step :come_on do
      sending :message, to: :romeo, body: "C'on, man!"
      checking :receipt
      checking :received
    end

    step :dying do
      sending :message, to: :romeo, body: "I'm dying!"
      checking :receipt
      checking :received
    end

    step :run_romeo do
      sending :message, to: :romeo, body: "Run Romeo!"
      checking :receipt
      checking :received
    end
  end

  logout()
end

# bots 1..100 do
#   set user: &"dancer#{&1["i"]}"
#   set password: "secret"
#   set domain: "shakespeare.im"
#   set host: "localhost"

#   set tls: false
#   set stream_mgmt: "disable"
#   set resource: "party"

#   login
#   wait_randomly_for bots: 10..15

#   run for: {:duration, 100}, as: :random do
#     step :sending do
#       sending :message, to: :bots, body_random: [
#         "Nice party!",
#         "Do you want to dance?",
#         "Excuse me!",
#         "Damn!"
#       ]
#       checking :receipt
#       checking :received
#       checking :displayed
#     end

#     maybe_and_repeat :receiving do
#       checking :message, from_random: fn("dancer" <> _) -> true end
#       sending :received
#       sending :displayed
#     end
#   end
#   logout
# end

show_stats for: [:romeo, :juliet, :mercutio]
