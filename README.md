# Bottle

Bottle XMPP Client let us test XMPP environments defining a couple of Elixir
scripting files for the stanza templates and the script to be followed by
the bot.

It let us to create as many connections as we need to test complex scenarios.

## Installation

The best way to get it is cloning from github:

```
git clone https://github.com/altenwald/bottle
```

And then build it up. It requires Erlang/OTP 22+ and Elixir 1.10+ installed
in your system. The building process is as follows:

```
mix do deps.get, escript.build
```

This will generate a `bottle` script binary (around of 1.2MB) with all of the
Elixir and Erlang code inside which will be needed to run the script. If you
want to use the script in another place, you only ensure you have installed
Erlang/OTP 22+ in that place.

## Templates

[exampple]: https://github.com/altenwald/exampple

The template file is where we define the stanzas we want to use inside of the
scenarios. This is a facility to let us to define the scenario in an easier way.
We have defined by default some templates which came from [Exampple][exampple]:

- `init/0`: the XML init or preamble. It's weird you will need it.
- `auth/2`: stanza to perform the plain authentication against the server. The two parameters are `user` and `password`.
- `bind/1`: stanza to bind the resource. The parameter which should be passed is the resource.
- `session/0`: stanza to create a session.
- `presence/0`: send a plain stanza to say to the server the user is connected.
- `message/3`: send a message to another user. The parameters are the user where you want to send the message, the ID for the stanza and a keyword list where we can set the payload as a normal XML data and the type for the message, or we can set the body as normal text setting the message as type chat.
- `iq/4`: send an IQ. The parameters are the destination, the ID, the type and a keyword where we can set namespace (xmlns) to send a simple query like ping, and additionally a payload to be included inside of the query, or only the payload to replace the query.
- `register/2`: performs a register request to the server. The parameters stands for user and password.

You can see an example of definition of new templates in the [templates.exs](templates.exs) file. This file is compulsory and will be searched by the script in the working path.

## Checks

Other facility Bottle gives you is the possibility to define checks. A check let us define a function which is going to be executed based on a specific situation to verify if the reception of the stanzas for a specific user follows the expected checks.

## Scenario

The `bottle` script admits one parameter to indicate the name of the _exs_ file to be loaded for the scenario definition. This file have the same format as you can see in our example [normal_clients.exs](normal_clients.exs).

The example file is showing an scenario where two users define a dataset, performs the
connection, login, binding, establishing the session and then the user1 sends a message to the user2. The user2 waits for that message and replies to the user1. Finally, both are disconnected and the running is stopped.

The dataset could contains the information needed based on the templates. You can see the use of these templates like:

```elixir
user1
|> Client.send_template(:auth, ["user", "pass"])
```

This code is using the dataset inside of `user1` and is requesting for the two parameters of the template, the data contained in the dataset with the keys as is in the last parameter of `send_template` function.

This means the `send_template` function is accepting the `user1` dataset, is going to use the `:auth` template and it's going to get the two needed parameters from the dataset using the `["user", "pass"]` as the keys to retrieve the parameters from the `user1` dataset.

As you can see, the population of the datase save us to indicate custom data again and again in different places.

## Bots

The bots concept is a way to create a new process which is running a whole behaviour in a constant way. The mission is the creation of bots which will be sending messages or creating an interaction between them in an autonomous way configured with templates and checks. An example:

```elixir
bot :romeo do
  set_from_file "romeo.exs"

  login()
  wait_for :julieta

  run for: :infinity, as: :ordered do
    step :sending do
      sending :chat, to: :julieta, body: "Oh! Julieta!"
      checking :receipt, from: :julieta
      checking :received, from: :julieta
      checking :displayed, from: :julieta
    end

    step :receiving do
      checking :chat, from: :julieta
      sending :received, to: :julieta
      sending :displayed, to: :julieta
    end

    maybe :from_mercutio do
      checking :chat, from: :mercutio
      sending :received, to: :mercutio
    end

    wait 1_000
  end

  logout()
end
```

More coming soon.

## Into the Shell

We can also perform the actions inside of the shell. If we run the project:

```
iex -S mix run
```

This is opening a shell using the file [.iex.exs](.iex.exs) available in the project and letting us to perform more customizations and interactivity with the flow. For example, if we want to write manually the message to be sent:

```elixir
user1
|> CLI.add_string("to", user2["user"] <> "@" <> user2["domain"])
|> CLI.add_string("type", "chat")
|> CLI.add_string("payload", "<body>Hello world!</body>")
|> Client.send_template(:message, ["to", "type", "payload"])
```

The use of the `CLI` module let us to check first the dataset. If the data isn't available, it asks us via _stdin_ what value we want to provide. And the last parameter correspond to the default value which will appear between square brackets just in case we want to press only enter and accept it.

Finally, when we call to the template, it has the needed parameters to work.

## Contributions

This code is part of the [Exampple][exampple] project. Feel free to open an issue in Github to give us some suggestions, catch a bug or ask anything. You can also send us a Pull Request if you want to provide a patch or a new feature.

Enjoy!
