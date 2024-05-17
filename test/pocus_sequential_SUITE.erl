%%%-------------------------------------------------------------------
%%%
%%%-------------------------------------------------------------------
-module(pocus_sequential_SUITE).
-compile(export_all).
-include_lib("common_test/include/ct.hrl").

%%--------------------------------------------------------------------
%% @spec suite() -> Info
%% Info = [tuple()]
%% @end
%%--------------------------------------------------------------------
suite() ->
    [{timetrap,{seconds,30}}].

%%--------------------------------------------------------------------
%% @spec init_per_suite(Config0) ->
%%     Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_suite(Config0) -> term() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%% @end
%%--------------------------------------------------------------------
end_per_suite(_Config) ->
    ok.

%%--------------------------------------------------------------------
%% @spec init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_group(_GroupName, Config) ->
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_group(GroupName, Config0) ->
%%               term() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% @end
%%--------------------------------------------------------------------
end_per_group(_GroupName, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% @spec init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_testcase(TestCase, Config0) ->
%%               term() | {save_config,Config1} | {fail,Reason}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
end_per_testcase(_TestCase, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% @spec groups() -> [Group]
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%% Shuffle = shuffle | {shuffle,{integer(),integer(),integer()}}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%% N = integer() | forever
%% @end
%%--------------------------------------------------------------------
groups() ->
    [].

%%--------------------------------------------------------------------
%% @spec all() -> GroupsAndTestCases | {skip,Reason}
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%% TestCase = atom()
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
all() ->
    [ simple
    , seed
    , roll
    % , trunc
    % , ripemd160
    % , sha
    % , sha224
    % , sha256
    % , sha384
    % , sha512
    % , sha3_224
    % , sha3_256
    % , sha3_384
    % , sha3_512
    % , md4
    % , md5
    ].

%%--------------------------------------------------------------------
%% @spec TestCase() -> Info
%% Info = [tuple()]
%% @end
%%--------------------------------------------------------------------
simple() ->
    [].

%%--------------------------------------------------------------------
%% @spec TestCase(Config0) ->
%%               ok | exit() | {skip,Reason} | {comment,Comment} |
%%               {save_config,Config1} | {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% Comment = term()
%% @end
%%--------------------------------------------------------------------
simple(_Config) ->
    {ok, Pid} = pocus_sequential:start_link(),

    % first hash
    ok = pocus_sequential:push(Pid, "test"),
    {ok, <<159,134,208,129,136,76,125,_/binary>>}
        = {ok, Hash1}
        = pocus_sequential:pull(Pid),

    % reinject previous hash
    ok = pocus_sequential:push(Pid, Hash1),
    {ok, <<114,7,159,203,43,56,25,213,76,_/binary>>}
        = {ok, _Hash2}
        = pocus_sequential:pull(Pid).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
seed() -> [].
seed(_Config) ->
    % start new process inialized with "test" string
    {ok, Pid} = pocus_sequential:start_link([{seed, "test"}]),
    {ok, <<159,134,208,129,136,76,125,_/binary>>}
        = pocus_sequential:pull(Pid).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
roll() -> [].
roll(_Config) ->
    % start new process inialized with "test" string
    {ok, Pid} = pocus_sequential:start_link([{seed, "test"}]),
    {ok, <<159,134,208,129,136,76,125,_/binary>>}
        = pocus_sequential:pull(Pid),

    % roll 1 time
    ok = pocus_sequential:roll(Pid),
    {ok, <<114,7,159,203,43,56,25,213,76,_/binary>>}
        = pocus_sequential:pull(Pid),

    % roll 1000 times
    ok = pocus_sequential:roll(Pid, 1000),
    {ok, <<234,70,240,114,239,91,78,203,_/binary>>}
        = pocus_sequential:pull(Pid).
