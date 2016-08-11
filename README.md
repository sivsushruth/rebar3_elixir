rebar3_elixir
=====

A rebar3 plugin to use elixir in your applications.


Use
---

Add the plugin to your rebar config:

    {plugins, [
        { rebar3_elixir, ".*", {git, "https://github.com/barrel-db/rebar3_elixir.git", {branch, "master"}}}
    ]}.

Then just call your plugin directly in an existing application:


    $ rebar3 rebar3_elixir
    ===> Fetching rebar3_elixir
    ===> Compiling rebar3_elixir
    <Plugin Output>
