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
%%%         init      |    |           |        |        |
%%%  ______/          |   _V___________V_      _|_____   |
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
%%%         init      |    |                                   |
%%%  ______/          |   _V_____________                      |
%%% |      |          |  |               |                     |
%%% | seed |---[hash]--->| hash_function |<--+                 |
%%% |______|          |  |_______________|   |                 |
%%%                   |    |                 |                 |
%%%                   |  [hash]           [hash]               |
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
%%% == Truncated Hash ==
%%%
%%% Generated hashes can be truncated. Truncated hashes are not
%%% necessirarily less secure, depending of the final result and the
%%% size of the removed data.
%%%
%%% ```
%%%  ______             ___________________________ process __
%%% |      |           /                                      \
%%% | push |---[data]------+                                   |
%%% |______|          |    |                                   |
%%%         init      |    |                                   |
%%%  ______/          |   _V_____________                      |
%%% |      |          |  |               |                     |
%%% | seed |---[hash]--->| hash_function |<-----+              |
%%% |______|          |  |_______________|      |              |
%%%                   |    |                    |              |
%%%                   |  [hash]              [thash]           |
%%%                   |    |                    |              |
%%%                   |   _V_____              _|________      |
%%%                   |  |       |            |          |     |
%%%                   |  | state |---[hash]-->| truncate |     |
%%%                   |  |_______|            |__________|     |
%%%                    \______________________________________/
%%%
%%%
%%% '''
%%%
%%% Here an example:
%%%
%%% ```
%%% % Start a new sequential state machine, truncating the
%%% % produced hash to 1 bit (on the left).
%%% {ok, Pid} = pocus_sequential:start_link([{trunc, 1}]).
%%%
%%% % hash a string and pack it.
%%% ok = pocus_sequential:push(Pid, "test").
%%%
%%% % only one bit is returned from the hash
%%% {ok, <<1:1>>} = pocus_sequential:package(Pid).
%%% '''
%%%
%%% == Rolling ==
%%%
%%% The output of a hash can be reused as input of the hash
%%% function. In this implementation, it's called `rolling'.
%%%
%%% ```
%%%                     ___________________________ process __
%%%         init       /                                      \
%%%  ______/          |   _______________                      |
%%% |      |          |  |               |                     |
%%% | seed |---[hash]--->| hash_function |<-----+              |
%%% |______|          |  |_______________|      |              |
%%%                   |    |                    |              |
%%%                   |  [hash]                 |              |
%%%                   |    |                    |              |
%%%  ______           |   _V_____               |              |
%%% |      |          |  |       |              |              |
%%% | roll |------------>| state |---[hash]-----+              |
%%% |______|          |  |_______|                             |
%%%                   |    |                                   |
%%%  ______           |    |                                   |
%%% |      |          |    |                                   |
%%% | pull |<--[hash]------+                                   |
%%% |______|          |                                        |
%%%                    \______________________________________/
%%%
%%%
%%% '''
%%%
%%% == Multi Hash Support ==
%%%
%%% This module supports all hashes supported by `crypto' module.
%%%
%%% == ETS Design (draft) ==
%%%
%%%
%%% ```
%%%  ______             _____________________ process __
%%% |      |           /                                \
%%% | push |---[data]------+                             |
%%% |______|          |    |                             |
%%%         init      |    |                             |
%%%  ______/          |   _V_____________                |
%%% |      |          |  |               |               |
%%% | seed |---[hash]--->| hash_function |               |
%%% |______|          |  |_______________|               |
%%%                   |    |                             |
%%%                   |  [pid,ts,hash]                   |
%%%                   |    |                             |
%%%                   |   _V_____                        |
%%%                   |  |       |                       |
%%%                   |  | state |                       |
%%%                   |  |_______|                       |
%%%                   |                                  |
%%%                    \________________________________/
%%%
%%%
%%% '''
%%%
%%% == Planning ==
%%%
%%% ```
%%%
%%% '''
%%%
%%%
%%% @end
%%%
%%% @todo creates types and do DRY on specification.
%%%
%%% @todo ensures documentation can be built.
%%%
%%% @todo increases test coverage.
%%%
%%% @todo defines terms used in this implementation.
%%%
%%% @todo adds complexity/safety analyzer features. The goal is to
%%%       have an idea of the entropy generated by the process.
%%%
%%% @todo adds ETS table support. The current model uses the memory
%%%       present in the process (heap/stack). Creating an ETS table
%%%       can help to export the data and do some computation on it.
%%%
%%% @todo adds a way to deal with distributed computation and
%%%       message ordering.
%%%
%%% @todo add support for streaming function: when needed a function
%%%       can be created, embedding a way to communicate with the
%%%       processus. binary, iodata and bitstring could be send and
%%%       retrieve with this function only.
%%%
%%% @todo add a "plan" support. when a message is pushed, it will
%%%       follow a plan, for example, roll + pack + roll + pack and so
%%%       on.
%%%
%%% @todo create a crack function to automatically execute a plan
%%%       and find a correspondance
%%%
%%%===================================================================
-module(pocus_sequential).
-behavior(gen_server).
% starters
-export([start_link/0, start_link/1, start_link/2]).
% call
-export([info/1, info/2]).
-export([pull/1, pull/2]).
-export([push_and_pull/2, push_and_pull/3]).
-export([pull_and_push/2, pull_and_push/3]).
-export([package/1, package/2]).
% cast
-export([push/2]).
-export([roll/1, roll/2]).
-export([push_and_pack/2, pack_and_push/2]).
-export([pack/1]).
-export([reset/1]).
% info
-export([drip/2]).
% gen_server handlers
-export([init/1]).
-export([handle_cast/2, handle_call/3, handle_info/2]).
-include_lib("kernel/include/logger.hrl").
-define(TIMEOUT, 10_000).

-record(?MODULE, { args            = []          :: proplists:proplists()
                 , hash            = sha256      :: atom()
                 , hash_size       = 256         :: pos_integer()
                 , hash_block_size = 512         :: pos_integer()
                 , hash_state      = undefined   :: undefined | reference()
                 , hash_import_state = undefined :: undefined | reference()
                 , pack            = []          :: list()
                 , pack_size       = 0           :: pos_integer()
                 , pack_limit      = undefined   :: pos_integer()
                 , seed            = undefined   :: binary()
                 , hash_trunc      = undefined   :: pos_integer()
                 , trunc_endian    = big         :: big | little
                 % access part
                 , mode            = public      :: public | private
                 , master_pid      = undefined   :: undefined | pid()
                 , master_node     = undefined   :: undefined | atom()
                 , start_time      = undefined   :: undefined | integer()
                 }).

-record(message, { node    :: atom()
                 , pid     :: pid()
                 , time    :: integer()
                 , payload :: term()
                 }).

%%--------------------------------------------------------------------
%% @doc start a new process with default parameters.
%% @see start_link/2
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, pid()}.

start_link() ->
    Message = message({start, []}),
    gen_server:start_link(?MODULE, Message, []).

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
    Message = message({start, Args}),
    gen_server:start_link(?MODULE, Message, []).

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
    Message = message({start, Args}),
    gen_server:start_link(?MODULE, Message, Opts).

%%--------------------------------------------------------------------
%% @doc API: returns process information.
%% @see info/2
%% @end
%%--------------------------------------------------------------------
-spec info(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: {ok, proplists:proplists()}.

info(Pid) ->
    info(Pid, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API: returns process information.
%% @end
%%--------------------------------------------------------------------
-spec info(Process, Timeout) -> Return when
      Process :: pid() | atom(),
      Timeout :: pos_integer(),
      Return  :: {ok, proplists:proplists()}.

info(Pid, Timeout) ->
    Message = message(info),
    gen_server:call(Pid, Message, Timeout).

%%--------------------------------------------------------------------
%% @doc API: Resets process state based on passed parameters during
%% initialization.
%% @end
%%--------------------------------------------------------------------
-spec reset(pid() | atom()) -> ok.

reset(Pid) ->
    Message = message(reset),
    gen_server:cast(Pid, Message).

%%--------------------------------------------------------------------
%% @doc API: Uses current hash state output as new data.
%% @see roll/2
%% @end
%%--------------------------------------------------------------------
-spec roll(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: ok.

roll(Pid) ->
    Message = message(roll),
    gen_server:cast(Pid, Message).

%%--------------------------------------------------------------------
%% @doc API: Uses curent hash state output as new data N times.
%% @end
%%--------------------------------------------------------------------
-spec roll(Process, LoopCounter) -> Return when
      Process     :: pid() | atom(),
      LoopCounter :: pos_integer(),
      Return      :: ok.

roll(Pid, Loop)
  when is_integer(Loop), Loop > 0 ->
    Message = message({roll, Loop}),
    gen_server:cast(Pid, Message).

%%--------------------------------------------------------------------
%% @doc API: Returns packaged hash.
%% @see package/2
%% @end
%%--------------------------------------------------------------------
-spec package(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: {ok, binary()} | timeout.

package(Pid) ->
    package(Pid, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API: Returns packaged hash.
%% @end
%%--------------------------------------------------------------------
-spec package(Process, Timeout) -> Return when
      Process :: pid() | atom(),
      Timeout :: pos_integer(),
      Return  :: {ok, binary()} | timeout.

package(Pid, Timeout) ->
    Message = message(package),
    gen_server:call(Pid, Message, Timeout).

%%--------------------------------------------------------------------
%% @doc API: Adds current hash state output into buffer (package).
%% @end
%%--------------------------------------------------------------------
-spec pack(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: ok.

pack(Pid) ->
    Message = message(pack),
    gen_server:cast(Pid, Message).

%%--------------------------------------------------------------------
%% @doc API: Pulls the current hash state output.
%% @end
%%--------------------------------------------------------------------
-spec pull(Process) -> Return when
      Process :: pid() | atom(),
      Return  :: {ok, binary()} | timeout.

pull(Pid) ->
    pull(Pid, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API: Pulls the current hash state output.
%% @end
%%--------------------------------------------------------------------
-spec pull(Process, Timeout) -> Return when
      Process :: pid() | atom(),
      Timeout :: pos_integer(),
      Return  :: {ok, binary()} | timeout.

pull(Pid, Timeout) ->
    Message = message(pull),
    gen_server:call(Pid, Message, Timeout).

%%--------------------------------------------------------------------
%% @doc API: Pushes new values into hash state.
%% @end
%%--------------------------------------------------------------------
-spec push(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: ok.

push(Pid, Data) ->
    Message = message({push, Data}),
    gen_server:cast(Pid, Message).

%%--------------------------------------------------------------------
%% @doc API: Pushes first and then pack.
%% @see push/2
%% @see pack/1
%% @end
%%--------------------------------------------------------------------
-spec push_and_pack(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: ok.

push_and_pack(Pid, Data) ->
    Message = message({push_and_pack, Data}),
    gen_server:cast(Pid, Message).

%%--------------------------------------------------------------------
%% @doc API: Packing first then pushes.
%% @see pack/1
%% @see push/2
%% @end
%%--------------------------------------------------------------------
-spec pack_and_push(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: ok.

pack_and_push(Pid, Data) ->
    Message = message({pack_and_push, Data}),
    gen_server:cast(Pid, Message).

%%--------------------------------------------------------------------
%% @doc API: Pushes first and then pull
%% @see push/2
%% @see pull/1
%% @end
%%--------------------------------------------------------------------
-spec push_and_pull(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: {ok, binary()} | timeout.

push_and_pull(Pid, Data) ->
    push_and_pull(Pid,  Data, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API: Pushes first and then pull
%% @end
%%--------------------------------------------------------------------
-spec push_and_pull(Process, Data, Timeout) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Timeout :: pos_integer(),
      Return  :: {ok, binary()} | timeout.

push_and_pull(Pid, Data, Timeout) ->
    Message = message({ push_and_pull, Data}),
    gen_server:call(Pid, Message, Timeout).

%%--------------------------------------------------------------------
%% @doc API: Pulling first and then pushing
%% @see pull/1
%% @see push/2
%% @end
%%--------------------------------------------------------------------
-spec pull_and_push(Process, Data) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Return  :: {ok, binary()} | timeout.

pull_and_push(Pid, Data) ->
    pull_and_push(Pid, Data, ?TIMEOUT).

%%--------------------------------------------------------------------
%% @doc API: Pulling first and then pushing
%% @end
%%--------------------------------------------------------------------
-spec pull_and_push(Process, Data, Timeout) -> Return when
      Process :: pid() | atom(),
      Data    :: string() | binary() | bitstring(),
      Timeout :: pos_integer(),
      Return  :: {ok, binary()} | timeout.

pull_and_push(Pid, Data, Timeout) ->
    Message = message({pull_and_push, Data}),
    gen_server:call(Pid, Message, Timeout).

%%--------------------------------------------------------------------
%% @doc API: Pushing a drip (binary/bitstring) values using standard
%% messages, can be used without using `gen_server' interfaces.
%% @end
%%--------------------------------------------------------------------
drip(Pid, Drip)
  when is_binary(Drip); is_bitstring(Drip) ->
    Message = message({drip, Drip}),
    Pid ! Message.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
message(Payload) ->
    #message{ node = node()
            , pid = self()
            , time = erlang:monotonic_time()
            , payload = Payload
            }.

%%--------------------------------------------------------------------
%% @hidden
%% @doc gen_server callback. Initializes FSM with arguments.
%% @end
%%--------------------------------------------------------------------
init(#message{ payload = {start, Args}
             , node = Node
             , pid = Pid
             , time = Time
             }) ->
    Mode = proplists:get_value(mode, Args, public),
    PackLimit = proplists:get_value(pack_limit, Args, undefined),
    InitState = #?MODULE{ args        = Args
                        , pack_limit  = PackLimit
                        , mode        = Mode
                        , master_pid  = Pid
                        , master_node = Node
                        , start_time  = Time
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
            #{ block_size := BlockSize
             , size := Size } = crypto:hash_info(Hash),
            NewState = InitState#?MODULE{ hash = Hash
                                        , hash_block_size = BlockSize * 8
                                        , hash_size = Size * 8
                                        },
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
            init_trunc(Args, State);
        _ when is_integer(PackSize), PackSize > 0 ->
            NewState = State#?MODULE{ pack_size = PackSize },
            init_trunc(Args, NewState);
        _ ->
            {error, [{pack_size, PackSize}]}
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
init_trunc(Args, State = #?MODULE{ hash_size = HashSize }) ->
    Trunc = proplists:get_value(trunc, Args, undefined),
    case Trunc of
        undefined ->
            init_final(Args, State);
        _ when is_integer(Trunc), Trunc > 0,  Trunc =< HashSize ->
            NewState = State#?MODULE{ hash_trunc = Trunc },
            init_final(Args, NewState);
        _ ->
            {error, [{trunc, Trunc}]}
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
handle_call( _Msg = #message{ node = Node
                            , pid = Pid
                            }
           , _From
           , State = #?MODULE{ mode = private
                             , master_pid = MasterPid
                             , master_node = MasterNode
                             })
  when {Node, Pid} =/= {MasterNode, MasterPid}  ->
    io:format("prout"),
    {noreply, State};
handle_call( Msg = #message{ payload = info }
           , From
           , State = #?MODULE{ hash = Hash
                             , args = Args
                             , pack_size = PackSize
                             , pack_limit = PackLimit
                             , seed = Seed
                             , mode = Mode
                             , master_pid = MasterPid
                             , master_node = MasterNode
                             , hash_trunc = Trunc
                             }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    Info = [ {hash, Hash}
           , {args, Args}
           , {pack_size, PackSize}
           , {pack_limit, PackLimit}
           , {seed, Seed}
           , {mode, Mode}
           , {master_pid, MasterPid}
           , {master_node, MasterNode}
           , {trunc, Trunc}
           ],
    {reply, {ok, Info}, State};
handle_call( Msg = #message{ payload = package }
           , From
           , State = #?MODULE{ pack = Pack }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    ReversedPack = lists:reverse(Pack),
    Output = << <<X/bitstring>> || X <- ReversedPack >>,
    {reply, {ok, Output}, State};
handle_call( Msg = #message{ payload = pull }
           , From
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    Output = hash_final(HashState, State),
    {reply, {ok, Output}, State};
handle_call( Msg = #message{ payload = {pull_and_push, Data} }
           , From
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, From, State}}]),
    Output = hash_final(HashState, State),
    NewHashState = hash_update(HashState, Data, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {reply, {ok, Output}, NewState};
handle_call( Msg = #message{ payload = {push_and_pull, Data} }
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
% private mode, don't answer.
handle_cast( _Msg = #message{ node = Node
                           , pid = Pid }
           , State = #?MODULE{ mode = private
                             , master_pid = MasterPid
                             , master_node = MasterNode
                             })
  when {Node, Pid} =/= {MasterNode, MasterPid}  ->
    {noreply, State};

% pack command, move output hash into buffer
handle_cast( Msg = #message{ payload = pack }
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

% push_and_pack command
handle_cast( Msg = #message{ payload = {push_and_pack, Data} }
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

% pack_and_push command
handle_cast( Msg = #message{ payload = {pack_and_push, Data} }
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

% push command
handle_cast( Msg = #message{ payload = {push, Data} }
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    NewHashState = hash_update(HashState, Data, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};

% roll command
handle_cast( Msg = #message{ payload = roll }
           , State = #?MODULE{ hash_state = HashState }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    Output = hash_final(HashState, State),
    NewHashState = hash_update(HashState, Output, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};

% roll command
handle_cast( Msg = #message{ payload = {roll, Counter} }
           , State = #?MODULE{}) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    NewHashState = roll_loop(Counter, State),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};

% reset command
handle_cast( Msg = #message{ payload = reset }
           , State = #?MODULE{ args = Args }) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
    {ok, InitState} = init(Args),
    {noreply, InitState}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc gen_server callback.
%% @end
%%--------------------------------------------------------------------
handle_info( _Msg = #message{ node = Node
                           , pid = Pid }
           , State = #?MODULE{ mode = private
                             , master_pid = MasterPid
                             , master_node = MasterNode
                             })
  when {Node, Pid} =/= {MasterNode, MasterPid}  ->
    {noreply, State};
handle_info( Msg = #message{ payload = {drip, Drip}}
           , State = #?MODULE{ hash_state = HashState })
  when is_binary(Drip); is_bitstring(Drip) ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, received, {Msg, State}}]),
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
-spec hash_init(Hash, State) -> Return when
      Hash :: atom(),
      State :: #?MODULE{},
      Return :: reference().

hash_init(Hash, _State) ->
    crypto:hash_init(Hash).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. wrapper around crypto:hash_update/2.
%% @end
%%--------------------------------------------------------------------
-spec hash_update(Reference, Data, State) -> Return when
      Reference :: reference(),
      Data :: string() | binary() | bitstring(),
      State :: #?MODULE{},
      Return :: reference().

hash_update(Reference, Data, _State = #?MODULE{ hash_size  = HashSize })
  when is_bitstring(Data), bit_size(Data) < HashSize  ->
    crypto:hash_update(Reference, <<Data:HashSize/bitstring>>);
hash_update(Reference, Data, _State) ->
    crypto:hash_update(Reference, Data).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. wrapper around crypto:hash_final/1.
%% @end
%%--------------------------------------------------------------------
-spec hash_final(Reference, State) -> Return when
      Reference :: reference(),
      State :: #?MODULE{},
      Return :: binary() | bitstring().

hash_final(Reference, _State = #?MODULE{ hash_trunc = Trunc
                                       , hash_size = HashSize
                                       , trunc_endian = big })
  when Trunc > 0 , Trunc < HashSize ->
    Output = crypto:hash_final(Reference),
    <<Truncated:Trunc/big-bitstring, _/bitstring>> = Output,
    Truncated;
hash_final(Reference, _State = #?MODULE{ hash_trunc = Trunc
                                       , hash_size = HashSize
                                       , trunc_endian = little })
  when Trunc > 0 , Trunc < HashSize ->
    Output = crypto:hash_final(Reference),
    <<Truncated:Trunc/little-bitstring, _/bitstring>> = Output,
    Truncated;
hash_final(Reference, _State) ->
    crypto:hash_final(Reference).
