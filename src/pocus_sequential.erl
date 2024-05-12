%%%===================================================================
%%% @author Mathieu Kerjouan
%%% @copyright (c) 2024 Mathieu Kerjouan
%%%
%%% @doc State machine Sequential hashing and hash packing
%%% implementation using `gen_server' behavior.
%%%
%%% This implementation is currently not safe in distributed
%%% environment. Messages ordering are not guaranteed.
%%%
%%% == Sequential Hashing ==
%%%
%%% Sequential Hashing refers to the process of applying a hash
%%% function to data sequentially. This could mean hashing data in a
%%% series where the output of hashing one piece of data may be used
%%% as input for the next hashing operation, or continuously feeding
%%% data into a hash function as it is received.
%%%
%%%
%%% ```
%%%  ______             _____________________ process __
%%% |      |           /                                \
%%% | push |---[data]------+           +-[hash]-+        |
%%% |______|          |    |           |        |        |
%%%                   |    |           |        |        |
%%%  ______           |   _V___________V_      _|_____   |
%%% |      |          |  |               |    |       |  |
%%% | seed |---[hash]--->| hash_function |--->| state |  |
%%% |______|          |  |_______________|    |_______|  |
%%%                   |                         |        |
%%%  ______            \________________________|_______/
%%% |      |                                    |
%%% | pull |<--[hash]---------------------------+
%%% |______|
%%%
%%% '''
%%%
%%% `push/2' function pushes data in hash function and update hash
%%% function state.
%%%
%%% `pull/1' function returns the current state of the hash function.
%%%
%%% ```
%%% % Start a new sequential state machine
%%% {ok, Pid} = pocus_sequential:start_link().
%%%
%%% % push a new string and retrieve its hash
%%% ok = pocus_sequential:push(Pid, "test").
%%% pocus_sequential:pull(Pid).
%%%
%%% % push a new string and retrieve the hash generated
%%% ok = pocus_sequential:push(Pid, "test").
%%% pocus_sequential:pull(Pid).
%%%
%%% % reset fsm to initial state.
%%% ok = pocus_sequential:reset(Pid).
%%% '''
%%%
%%% == Hach Packing ==
%%%
%%% Hash packing can be interpreted as a method where multiple
%%% discrete data items are combined into a single composite data
%%% structure and then hashed using a cryptographic hash function to
%%% produce a single output hash.
%%%
%%%
%%% ```
%%%  ______             ___________________________ process __
%%% |      |           /                                      \
%%% | push |---[data]------+                                   |
%%% |______|          |    |                                   |
%%%                   |    |                                   |
%%%  ______           |   _V_____________                      |
%%% |      |          |  |               |                     |
%%% | seed |---[hash]--->| hash_function |<--+                 |
%%% |______|          |  |_______________|   |                 |
%%%                   |    |                 |                 |
%%%  ______           |   _V_____            |     ________    |
%%% |      |          |  |       |           |    |        |   |
%%% | pack |------------>| state |---[hash]--+--->| buffer |   |
%%% |______|          |  |_______|                |________|   |
%%%                    \____________________________|_________/
%%%  _________                                      |
%%% |         |                                     |
%%% | package |<--[hash]----------------------------+
%%% |_________|
%%%
%%%
%%% '''
%%%
%%% `push/2' function pushes data in hash function and update hash
%%% function state.
%%%
%%% `pack/1' function pushes current hash (from hash state) into a
%%% buffer.
%%%
%%% `package/1' function returns the buffer as binary.
%%%
%%% `pack_and_push/2' function pack the current hash and push data to
%%% update the hash state.
%%%
%%% `push_and_pack/2' function push new data and update hash state and
%%% then append the value into buffer.
%%%
%%%
%%% ```
%%% % Start a new sequential state machine
%%% {ok, Pid} = pocus_sequential:start_link().
%%%
%%% % hash a string and pack it.
%%% ok = pocus_sequential:push(Pid, "test").
%%% ok = pocus_sequential:pack(Pid).
%%%
%%% % hash another string and pack it.
%%% ok = pocus_sequential:push(Pid, "test").
%%% ok = pocus_sequential:pack(Pid).
%%%
%%% % get the pack
%%% pocus_sequential:package(Pid).
%%%
%%% % reset fsm state
%%% pocus_sequential:reset(Pid).
%%% '''
%%%
%%% @end
%%%
%%% @todo add hash_trunc feature to truncate data before being added
%%%       into pack buffer
%%% @todo creates types and do DRY on specificatoin
%%% @todo ensures documentation can be built
%%% @todo increases test coverage
%%% @todo defines terms used in this implementation
%%% @todo adds complexity analyzer features
%%%===================================================================
-module(pocus_sequential).
-export([start_link/0, start_link/1, start_link/2]).
-export([info/1, pull/1, push/2, drip/2]).
-export([roll/1, roll/2]).
-export([push_and_pull/2, pull_and_push/2]).
-export([push_and_pack/2, pack_and_push/2]).
-export([package/1, pack/1]).
-export([reset/1]).
-export([init/1]).
-export([handle_cast/2, handle_call/3, handle_info/2]).
-include_lib("kernel/include/logger.hrl").
-define(TIMEOUT, 10_000).
-behavior(gen_server).
-record(?MODULE, { args       = []
                 , hash       = sha256
                 , hash_state = undefined
                 , hash_import_state = undefined
                 , pack       = []
                 , pack_size  = 0
                 , pack_limit = undefined
                 , seed       = undefined
                 }).

%%--------------------------------------------------------------------
%% @doc start a new process with default parameters.
%% @see start_link/2
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, pid()}.

start_link() ->
    gen_server:start_link(?MODULE, [], []).

%%--------------------------------------------------------------------
%% @doc start a new process with custom parameters.
%% @see start_link/2
%% @end
%%--------------------------------------------------------------------
-spec start_link(Args) -> Return when
      Args   :: [Arg, ...],
      Arg    :: {seed, binary()}
              | {hash, atom() | sha | sha256 | sha512}
              | {hash_state, reference()}
              | {pack_limit, pos_integer()},
      Return :: {ok, pid()}.

start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

%%--------------------------------------------------------------------
%% @doc start a new process with custom parameters and custom
%% gen_statem options.
%% @end
%%--------------------------------------------------------------------
-spec start_link(Args, Opts) -> Return when
      Args   :: [Arg, ...],
      Arg    :: {seed, binary()}
              | {hash, atom() | sha | sha256 | sha512}
              | {hash_state, reference()}
              | {pack_limit, pos_integer()},
      Opts   :: [term()],
      Return :: {ok, pid()}.

start_link(Args, Opts) ->
    gen_server:start_link(?MODULE, Args, Opts).

%%--------------------------------------------------------------------
%% @doc API. Resets process state based on passed parameters during
%% initialization.
%% @end
%%--------------------------------------------------------------------
-spec info(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: {ok, proplists:proplists()}.

info(Pid) ->
    gen_server:call(Pid, info, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API. Resets process state based on passed parameters during
%% initialization.
%% @end
%%--------------------------------------------------------------------
-spec reset(pid() | atom()) -> ok.

reset(Pid) ->
    gen_server:cast(Pid, reset).

%%--------------------------------------------------------------------
%% @doc API. Uses current hash state output as new data.
%% @see roll/2
%% @end
%%--------------------------------------------------------------------
-spec roll(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: ok.

roll(Pid) ->
    gen_server:cast(Pid, roll).

%%--------------------------------------------------------------------
%% @doc API. Uses curent hash state output as new data N times.
%% @end
%%--------------------------------------------------------------------
-spec roll(Process, LoopCounter) -> Return when
      Process     :: pid() | atom(),
      LoopCounter :: pos_integer(),
      Return      :: ok.

roll(Pid, Loop)
  when is_integer(Loop), Loop > 0 ->
    gen_server:cast(Pid, {roll, Loop}).

%%--------------------------------------------------------------------
%% @doc API. Returns packaged hash.
%% @end
%%--------------------------------------------------------------------
-spec package(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: {ok, binary()} | timeout.

package(Pid) ->
    gen_server:call(Pid, package, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API. Adds current hash state output into buffer (package).
%% @end
%%--------------------------------------------------------------------
-spec pack(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: ok.

pack(Pid) ->
    gen_server:cast(Pid, pack).

%%--------------------------------------------------------------------
%% @doc API. Pulls the current hash state output.
%% @end
%%--------------------------------------------------------------------
-spec pull(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: {ok, binary()} | timeout.

pull(Pid) ->
    gen_server:call(Pid, pull, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API. Pushes new values into hash state.
%% @end
%%--------------------------------------------------------------------
-spec push(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: ok.

push(Pid, Data) ->
    gen_server:cast(Pid, {push, Data}).

%%--------------------------------------------------------------------
%% @doc API. Pushes first and then pack.
%% @see push/2
%% @see pack/1
%% @end
%%--------------------------------------------------------------------
-spec push_and_pack(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: ok.

push_and_pack(Pid, Data) ->
    gen_server:cast(Pid, {push_and_pack, Data}).

%%--------------------------------------------------------------------
%% @doc API. Packing first then pushes.
%% @see pack/1
%% @see push/2
%% @end
%%--------------------------------------------------------------------
-spec pack_and_push(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: ok.

pack_and_push(Pid, Data) ->
    gen_server:cast(Pid, {pack_and_push, Data}).

%%--------------------------------------------------------------------
%% @doc API. Pushes first and then pull
%% @see push/2
%% @see pull/1
%% @end
%%--------------------------------------------------------------------
-spec push_and_pull(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: {ok, binary()} | timeout.

push_and_pull(Pid, Data) ->
    gen_server:call(Pid, {push_and_pull, Data}, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API. Pulling first and then pushing
%% @see pull/1
%% @see push/2
%% @end
%%--------------------------------------------------------------------
-spec pull_and_push(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: {ok, binary()} | timeout.

pull_and_push(Pid, Data) ->
    gen_server:call(Pid, {pull_and_push, Data}, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API. Pushing a drip (binary/bitstring) values using standard
%% messages, can be used without using `gen_server' interfaces.
%% @end
%%--------------------------------------------------------------------
drip(Pid, Drip)
  when is_binary(Drip); is_bitstring(Drip) ->
    Pid ! {drip, Drip}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc gen_server callback. Initializes FSM with arguments.
%% @end
%%--------------------------------------------------------------------
init(Args) ->
    PackLimit = proplists:get_value(pack_limit, Args, undefined),
    InitState = #?MODULE{ args = Args
                        , pack_limit = PackLimit
                        },
    init_hash(Args, InitState).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function, initialize hash state.
%% @end
%%--------------------------------------------------------------------
init_hash(Args, InitState) ->
    Hash = proplists:get_value(hash, Args, sha256),
    Supports = crypto:supports(hashs),
    CheckSupports = fun(X) -> X =:= Hash end,
    case lists:filter(CheckSupports, Supports) of
        [] ->
            {error, [{hash, Hash}]};
        [_|_] ->
            NewState = InitState#?MODULE{ hash = Hash },
            init_import(Args, NewState)
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. external state import
%% @end
%%--------------------------------------------------------------------
init_import(Args, State = #?MODULE{ hash = Hash }) ->
    ImportedHashState = proplists:get_value(hash_state, Args, undefined),
    case ImportedHashState of
        undefined ->
            HashState = hash_init(Hash, State),
            NewState = State#?MODULE{ hash_state = HashState },
            init_seed(Args, NewState);
        Reference
          when is_reference(Reference) ->
            NewState = State#?MODULE{ hash_state = Reference
                                    , hash_import_state = Reference
                                    },
            init_seed(Args, NewState);
        _ ->
            {error, [{hash_state, ImportedHashState}]}
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. seed initialization.
%% @end
%%--------------------------------------------------------------------
init_seed(Args, State = #?MODULE{ hash_state = HashState }) ->
    Seed = proplists:get_value(seed, Args, undefined),
    case Seed of
        undefined ->
            init_pack_size(Args, State);
        _ when is_binary(Seed); is_list(Seed); is_bitstring(Seed) ->
            NewHashState = hash_update(HashState, Seed, State),
            NewState = State#?MODULE{ hash_state = NewHashState },
            init_pack_size(Args, NewState);
        _ ->
            {error, [{seed, Seed}]}
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
init_pack_size(Args, State) ->
    PackSize = proplists:get_value(pack_size, Args, undefined),
    case PackSize of
        undefined ->
            init_final(Args, State);
        _ when is_integer(PackSize), PackSize > 0 ->
            NewState = State#?MODULE{ pack_size = PackSize },
            init_final(Args, NewState);
        _ ->
            {error, [{pack_size, PackSize}]}
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. final state initialization.
%% @end
%%--------------------------------------------------------------------
init_final(_Args, State) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc gen_server callback.
%% @end
%%--------------------------------------------------------------------
handle_call( Msg = info
           , From
           , State = #?MODULE{ hash = Hash
                             , args = Args
                             , pack_size = PackSize
                             , pack_limit = PackLimit
                             , seed = Seed
                             }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    Info = [ {hash, Hash}
           , {args, Args}
           , {pack_size, PackSize}
           , {pack_limit, PackLimit}
           , {seed, Seed}
           ],
    {reply, {ok, Info}, State};
handle_call( Msg = package
           , From
           , State = #?MODULE{ pack = Pack }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    ReversedPack = lists:reverse(Pack),
    Output = << <<X/binary>> || X <- ReversedPack >>,
    {reply, {ok, Output}, State};
handle_call( Msg = pull
           , From
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    Output = hash_final(HashState, State),
    {reply, {ok, Output}, State};
handle_call( Msg = {pull_and_push, Data}
           , From
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    Output = hash_final(HashState, State),
    NewHashState = hash_update(HashState, Data, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {reply, {ok, Output}, NewState};
handle_call( Msg = {push_and_pull, Data}
           , From
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    NewHashState = hash_update(HashState, Data, State),
    Output = hash_final(NewHashState, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {reply, {ok, Output}, NewState}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc gen_server callback.
%% @end
%%--------------------------------------------------------------------
handle_cast(Msg = pack
           , State = #?MODULE{ hash_state = HashState
                             , pack = Pack
                             , pack_size = PackSize
                             , pack_limit = PackLimit
                             }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    case PackSize =< PackLimit of
        true ->
            Output = hash_final(HashState, State),
            Buffer = [Output|Pack],
            NewState = State#?MODULE{ pack = Buffer },
            {noreply, NewState};
        false ->
            {noreply, State}
    end;
handle_cast( Msg = {push_and_pack, Data}
           , State = #?MODULE{ hash_state = HashState
                             , pack = Pack
                             , pack_size = PackSize
                             , pack_limit = PackLimit
                             }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    case PackSize =< PackLimit of
        true ->
            NewHashState = hash_update(HashState, Data, State),
            Output = hash_final(NewHashState, State),
            Buffer = [Output|Pack],
            NewState = State#?MODULE{ hash_state = NewHashState
                                    , pack = Buffer
                                    },
            {noreply, NewState};
        false ->
            {noreply, State}
    end;
handle_cast( Msg = {pack_and_push, Data}
           , State = #?MODULE{ hash_state = HashState
                             , pack = Pack
                             , pack_size = PackSize
                             , pack_limit = PackLimit
                             }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    case PackSize =< PackLimit of
        true ->
            Output = hash_final(HashState, State),
            NewHashState = hash_update(HashState, Data, State),
            Buffer = [Output|Pack],
            NewState = State#?MODULE{ hash_state = NewHashState
                                    , pack = Buffer
                                    },
            {noreply, NewState};
        false ->
            {noreply, State}
    end;
handle_cast( Msg = {push, Data}
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    NewHashState = hash_update(HashState, Data, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};
handle_cast( Msg = roll
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    Output = hash_final(HashState, State),
    NewHashState = hash_update(HashState, Output, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};
handle_cast(Msg = {roll, Counter}, State = #?MODULE{}) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    NewHashState = roll_loop(Counter, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};
handle_cast( Msg = reset
           , State = #?MODULE{ args = Args }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    {ok, InitState} = init(Args),
    {noreply, InitState}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc gen_server callback.
%% @end
%%--------------------------------------------------------------------
handle_info({drip, Drip}, State = #?MODULE{ hash_state = HashState })
  when is_binary(Drip); is_bitstring(Drip) ->
    NewHashState = hash_update(HashState, Drip, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};
handle_info(Msg, State) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. "rolls" the hash with its own output.
%% @end
%%--------------------------------------------------------------------
roll_loop(Counter, State = #?MODULE{ hash_state = HashState })
  when is_integer(Counter), Counter > 0 ->
    roll_loop(HashState, Counter, State).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. "rolls" the hash with its own output.
%% @end
%%--------------------------------------------------------------------
roll_loop(HashState, 0, _State) ->
    HashState;
roll_loop(HashState, Counter, State) ->
    Output = hash_final(HashState, State),
    NewHashState = hash_update(HashState, Output, State),
    roll_loop(NewHashState, Counter-1, State).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. wrapper around crypto:hash_init/1.
%% @end
%%--------------------------------------------------------------------
hash_init(Hash, _State) ->
    crypto:hash_init(Hash).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. wrapper around crypto:hash_update/2.
%% @end
%%--------------------------------------------------------------------
hash_update(Reference, Data, _State) ->
    crypto:hash_update(Reference, Data).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. wrapper around crypto:hash_final/1.
%% @end
%%--------------------------------------------------------------------
hash_final(Reference, _State) ->
    crypto:hash_final(Reference).
