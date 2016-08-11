-module(rebar3_elixir_prv_ex_compiler).

-export([init/1, do/1, format_error/1]).

-define(PROVIDER, compile).
-define(DEPS, [{default, app_discovery}]).
-define(NAMESPACE, ex).

-define(ELIXIR_APPS, ["elixir", "mix", "logger", "iex", "ex_unit"]).

-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    Provider = providers:create([
            {name, ?PROVIDER},
            {namespace, ?NAMESPACE},
            {module, ?MODULE},     
            {bare, true},
            {deps, ?DEPS},
            {example, "rebar3 rebar3_elixir"},
            {opts, []},
            {short_desc, "A rebar plugin"},
            {desc, "A rebar plugin"}
    ]),
    {ok, rebar_state:add_provider(State, Provider)}.


-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->  
    add_elixir_libs(State),
    {ok, State}.

add_elixir_libs(State) ->
    rebar_api:console("===> Adding Elixir Libs ~p", []),
    MixState = add_elixir(State),
    compile_libs(MixState),
    ok.

add_elixir(State) ->
    RebarConfig = rebar_file_utils:try_consult(rebar_dir:root_dir(State) ++ "/rebar.config"),
    {elixir_opts, Config} = lists:keyfind(elixir_opts, 1, RebarConfig),
    {lib_dir, LibDir} = lists:keyfind(lib_dir, 1, Config),
    {bin_dir, BinDir} = lists:keyfind(bin_dir, 1, Config),
    {env, Env} = lists:keyfind(env, 1, Config),
    MixState = add_states(State, BinDir, Env),
    code:add_patha(LibDir ++ "/elixir/ebin"),
    code:add_patha(LibDir ++ "/mix/ebin"),
    MixState.

add_states(State, BinDir, Env) ->
    EnvState = rebar_state:set(State, mix_env, Env),
    ElixirState = rebar_state:set(EnvState, elixir, BinDir ++ "/elixir "),
    rebar_state:set(ElixirState, mix, BinDir ++ "/mix ").    

compile_libs(State) ->
    {ok, Apps} = rebar_utils:list_dir(rebar_dir:root_dir(State) ++ "/elixir_libs"),
    compile_libs(State, Apps).

compile_libs(State, []) ->
    ok;          

compile_libs(State, [App | Apps]) ->
    AppDir = rebar_dir:root_dir(State) ++ "/elixir_libs/" ++ App,
    Mix = rebar_state:get(State, mix),
    Env = rebar_state:get(State, mix_env),
    Profile = case Env of
        dev -> ""; 
        prod -> "MIX_ENV=prod "
    end,    
    rebar_utils:sh(Profile ++ Mix ++ "deps.get", [{cd, AppDir}, {use_stdout, true}]),
    rebar_utils:sh(Profile ++ Mix ++ "compile", [{cd, AppDir}, {use_stdout, true}]),
    LibsDir = filename:join([AppDir, "_build/", Env , "lib/"]),
    {ok, Libs} = file:list_dir_all(LibsDir),
    transfer_libs(State, Libs, LibsDir),
    compile_libs(State, Apps).

transfer_libs(State, [], LibsDir) ->
    ok;

transfer_libs(State, [Lib | Libs], LibsDir) ->
    DepsDir = rebar_dir:deps_dir(State),
    maybe_copy_dir(LibsDir ++ "/" ++ Lib, DepsDir),
    transfer_libs(State, Libs, LibsDir).

maybe_copy_dir(Source, Target) ->
    TargetApp = lists:last(filename:split(Source)),
    case filelib:is_dir(Target ++ TargetApp) of
        true -> ok;
        false -> rebar_file_utils:cp_r([Source], Target)
    end.    
    
-spec format_error(any()) ->  iolist().
format_error(Reason) ->
    io_lib:format("~p", [Reason]).

maybe_clear_dir(Dir) ->
    case filelib:is_dir(Dir) of
        true -> ec_file:remove(Dir, [recursive]);
        false -> false
    end.