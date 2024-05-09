%%%===================================================================
%%% @doc
%%% @end
%%%===================================================================
-module(pocus_prng).
-compile(export_all).
-behavior(gen_server).
-record(?MODULE, { store = <<>> 
                 , seed = <<>>
                 }).

init(_Args) ->
    Seed = crypto:strong_rand_bytes(1024),
    {ok, #?MODULE{ seed = Seed }}.

handle_call({get, Size}, _From, State) ->
    case get_value(Size, State) of
        {ok, Value, NewState} ->
            {reply, {ok, Value}, NewState};
        {error, NewState} ->
            {reply, error, NewState}
    end.

handle_cast({event, Event}, State) ->
    update_store(Event, State).

handle_info({event, Event}, State) ->
    update_store(Event, State).

get_value(Size, #?MODULE{ store = Store } = State) ->
    try 
        <<Value:Size/binary, Rest/binary>> = Store,
        {ok, Value, #?MODULE{ store = Rest }}
    catch
        _:_:_ -> {error, State}
    end.

update_store(Event, #?MODULE{ store = Store }) ->
    Bin = term_to_binary(Event),
    crypto:hash(sha256, Bin).
