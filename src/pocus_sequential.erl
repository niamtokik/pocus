%%%===================================================================
%%% @author Mathieu Kerjouan
%%% @copyright (c) 2024 Mathieu Kerjouan
%%% @doc
%%% @end
%%% @todo add hash_trunc feature
%%%===================================================================
-module(pocus_sequential).
-export([start_link/0, start_link/1, start_link/2]).
-export([pull/1, push/2]).
-export([push_and_pull/2, pull_and_push/2]).
-export([push_and_pack/2, pack_and_push/2]).
-export([package/1, pack/1]).
-export([reset/1]).
-export([init/1]).
-export([handle_cast/2, handle_call/3, handle_info/2]).
-behavior(gen_server).
-record(?MODULE, { hash       = sha256 
                 , hash_state = undefined
                 , pack       = []
                 , pack_size  = 0
                 , pack_limit = undefined
                 , seed       = undefined
                 }).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link(?MODULE, [], []).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
start_link(Args, Opts) ->
    gen_server:start_link(?MODULE, Args, Opts).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
reset(Pid) ->
    gen_server:cast(Pid, reset).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
package(Pid) ->
    gen_server:call(Pid, package, 10_000).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
pack(Pid) ->
    gen_server:cast(Pid, pack).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
pull(Pid) ->
    gen_server:call(Pid, pull, 10_000).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
push(Pid, Data) ->
    gen_server:cast(Pid, {push, Data}).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
push_and_pack(Pid, Data) ->
    gen_server:cast(Pid, {push_and_pack, Data}).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
pack_and_push(Pid, Data) ->
    gen_server:cast(Pid, {pack_and_push, Data}).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
push_and_pull(Pid, Data) ->
    gen_server:call(Pid, {push_and_pull, Data}, 10_000).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
pull_and_push(Pid, Data) ->
    gen_server:call(Pid, {pull_and_push, Data}, 10_000).

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
init(Args) ->
    PackLimit = proplists:get_value(pack_limit, Args, undefined),
    InitState = #?MODULE{ pack_limit = PackLimit },
    init_hash(Args, InitState).

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
init_hash(Args, InitState) ->
    Hash = proplists:get_value(hash, Args, sha256),
    NewState = InitState#?MODULE{ hash = Hash },
    init_import(Args, NewState).

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
init_import(Args, State = #?MODULE{ hash = Hash }) ->
    ImportedHashState = proplists:get_value(hash_state, Args, undefined),
    case ImportedHashState of
        undefined ->
            HashState = crypto:hash_init(Hash),
            NewState = State#?MODULE{ hash_state = HashState },
            init_seed(Args, NewState);
        Reference 
          when is_reference(Reference) ->
            NewState = State#?MODULE{ hash_state = Reference },
            init_seed(Args, NewState)
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
init_seed(Args, State = #?MODULE{ hash_state = HashState }) ->
    Seed = proplists:get_value(seed, Args, undefined),
    case Seed of
        undefined ->
            init_final(Args, State);
        Value ->
            NewHashState = crypto:hash_update(HashState, Value),
            NewState = State#?MODULE{ hash_state = NewHashState },
            init_final(Args, NewState)
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
init_final(_Args, State) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
handle_call( package, _From
           , State = #?MODULE{ pack = Pack }) ->
    ReversedPack = lists:reverse(Pack),
    Result = << <<X/binary>> || X <- ReversedPack >>,
    {reply, Result, State};
handle_call( pull, _From
           , State = #?MODULE{ hash_state = HashState }) ->
    Value = crypto:hash_final(HashState),
    {reply, Value, State};
handle_call( {pull_and_push, Data}, _From
           , State = #?MODULE{ hash_state = HashState }) ->
    Current = crypto:hash_final(HashState),
    NewHashState = crypto:hash_update(HashState, Data),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {reply, Current, NewState};
handle_call( {push_and_pull, Data}, _From
           , State = #?MODULE{ hash_state = HashState }) ->
    NewHashState = crypto:hash_update(HashState, Data),
    Current = crypto:hash_final(NewHashState),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {reply, Current, NewState}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
handle_cast(pack, State = #?MODULE{ hash_state = HashState
                                  , pack = Pack 
                                  , pack_size = PackSize
                                  , pack_limit = PackLimit
                                  }) ->    
    case PackSize =< PackLimit of
        true ->
            Result = crypto:hash_final(HashState),
            NewState = State#?MODULE{ pack = [Result|Pack] },
            {noreply, NewState};
        false ->
            {noreply, State}
    end;
handle_cast( {push_and_pack, Data}
           , State = #?MODULE{ hash_state = HashState
                             , pack = Pack 
                             , pack_size = PackSize
                             , pack_limit = PackLimit
                             }) ->
    case PackSize =< PackLimit of
        true ->    
            NewHashState = crypto:hash_update(HashState, Data),
            Result = crypto:hash_final(NewHashState),
            NewState = State#?MODULE{ hash_state = NewHashState
                                    , pack = [Result|Pack]
                                    },
            {noreply, NewState};
        false ->
            {noreply, State}
    end;
handle_cast( {pack_and_push, Data}
           , State = #?MODULE{ hash_state = HashState
                             , pack = Pack 
                             , pack_size = PackSize
                             , pack_limit = PackLimit 
                             }) ->
    case PackSize =< PackLimit of
        true ->        
            Result = crypto:hash_final(HashState),
            NewHashState = crypto:hash_update(HashState, Data),
            NewState = State#?MODULE{ hash_state = NewHashState
                                    , pack = [Result|Pack]
                                    },
            {noreply, NewState};
        false ->
            {noreply, State}
    end;
handle_cast({push, Data}, State = #?MODULE{ hash_state = HashState }) ->
    NewHashState = crypto:hash_update(HashState, Data),
    NewState = State#?MODULE{ hash_state = NewHashState },
    {noreply, NewState};
handle_cast(reset, State) ->    
    {noreply, State}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
handle_info(_Message, State) ->
    {noreply, State}.
