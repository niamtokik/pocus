%%%===================================================================
%%% Copyright (c) 2024 Mathieu Kerjouan
%%%
%%% Permission to use, copy, modify, and distribute this software for
%%% any purpose with or without fee is hereby granted, provided that
%%% the above copyright notice and this permission notice appear in
%%% all copies.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
%%% WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
%%% WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
%%% AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
%%% CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
%%% LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
%%% NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
%%% CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
%%%
%%% @author Mathieu Kerjouan
%%% @copyright 2024 Mathieu Kerjouan
%%%===================================================================
-module(pocus).
-export([execute/0, execute/1, execute/3]).
-export([sequential/1, sequential/2]).
-export([sequential_par/1, sequential_par_spawn/2]).
-export([packing/1, packing/2]).
-export([chunk/3, chunk_par/2, chunk_spawn/5]).
-export([prf_def/1, prf_def/2]).
-export([merkle/2, merkle/3]).
-export([take/2]).
-include("pocus.hrl").
-include("pocus_types.hrl").
-include_lib("kernel/include/logger.hrl").
-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% @doc main functions to execute the exercice, using random values.
%% @end
%%--------------------------------------------------------------------
-spec execute() -> Return when
      Struct :: #{ block => binary()
                 , miner => binary()
                 , secret => binary()
                 , merkle => binary()
                 },
      Return :: {ok, Struct}.

execute() ->
    % default block size: 65536 bytes (64*1024)
    Block = crypto:strong_rand_bytes(64*1024),

    % default miner address: 32 bytes
    Miner = crypto:strong_rand_bytes(32),

    % default secret: 32 bytes
    Secret = crypto:strong_rand_bytes(32),
    execute(Block, Miner, Secret).

%%--------------------------------------------------------------------
%% @doc verify a merkle tree.
%% @end
%%--------------------------------------------------------------------
-spec execute(Struct) -> Return when
      Struct :: #{ block => binary()
                 , miner => binary()
                 , secret => binary()
                 , merkle => binary()
                 },
      Return :: boolean().

execute(#{ block := Block, miner := Miner, secret := Secret, merkle := Merkle }) ->
    {ok, #{ merkle := Result }} = execute(Block, Miner, Secret),
    Result =:= Merkle.

%%--------------------------------------------------------------------
%% @doc generates a merkle tree.
%% @end
%%--------------------------------------------------------------------
-spec execute(Block, Miner, Secret) -> Return when
      Block  :: binary(),
      Miner  :: binary(),
      Secret :: binary(),
      Struct :: #{ block => binary()
                 , miner => binary()
                 , secret => binary()
                 , merkle => binary()
                 },
      Return :: {ok, Struct}.

execute(<<Block:(64*1024)/binary>>, <<Miner:32/binary>>, <<Secret:32/binary>>) ->
    io:format("block: ~P~n", [Block,10]),
    io:format("miner: ~P~n", [Miner,10]),
    io:format("secret: ~P~n", [Secret,10]),
    io:format("hash round: ~p~n", [?SEQUENTIAL_LOOP]),

    io:format("generates hash list... "),
    HashList = [ crypto:hash(?HASH, <<Increment/binary, Miner/binary>>)
                 || <<Increment:32/binary>> <= Block ],
    io:format("done: ~P~n", [HashList,10]),

    io:format("sequential hashing... "),
    HashRound = << <<(sequential(Hash, ?SEQUENTIAL_LOOP))/binary>>
                   || Hash <- HashList >>,
    io:format("done: ~P~n", [HashRound,10]),

    io:format("generates chunks... "),
    ChunksList = [ <<Chunk/binary>> || <<Chunk:32/binary>> <= HashRound ],
    Chunks = << <<X/binary>> || X <- ChunksList >>,
    io:format("done: ~P~n", [Chunks,10]),

    io:format("generates merkle... "),
    Merkle = merkle(Chunks, Secret),
    io:format("done: ~P~n", [Merkle,10]),

    {ok, #{ block  => Block
          , miner  => Miner
          , secret => Secret
          , merkle => Merkle
          }
    }.

%%--------------------------------------------------------------------
%% @doc generates 10 hashes and concatenate them to generate a part of
%% a merkle tree.
%%
%% @see merkle/3
%% @end
%%--------------------------------------------------------------------
-spec merkle(Chunks, Secret) -> Return when
      Chunks :: binary(),
      Secret :: binary(),
      Return :: binary().

merkle(Chunks, Secret) ->
    merkle(Chunks, Secret, 10).

%%--------------------------------------------------------------------
%% @doc generates a merkle tree as binary with custom limit.
%% @end
%%--------------------------------------------------------------------
-spec merkle(Chunks, Secret, Limit) -> Return when
      Chunks :: binary(),
      Secret :: binary(),
      Limit  :: pos_integer(),
      Return :: binary().

merkle(Chunks, Secret, Limit)
  when Limit > 0 ->
    merkle(Chunks, Secret, Limit, []).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. Generate a list of hash.
%% @end
%%--------------------------------------------------------------------
-spec merkle(Chunks, Secret, Limit, Buffer) -> Return when
      Chunks :: binary(),
      Secret :: binary(),
      Limit :: pos_integer(),
      Buffer :: [binary()],
      Return :: binary().

merkle(_, _, 0, Buffer) ->
    Reversed = lists:reverse(Buffer),
    << <<X/binary>> || X <- Reversed >>;
merkle(Chunks, Secret, Limit, Buffer) ->
    Offset = prf_def(Secret),
    <<_:(Offset*32)/binary, OffsetValue:32/binary, _/binary>> = Chunks,
    Hash = crypto:hash(?HASH, OffsetValue),
    merkle(Chunks, Hash, Limit-1, [Hash|Buffer]).

%%--------------------------------------------------------------------
%% @doc quick and dirty pseudo determinist functions using 2048 as
%% modulo.
%%
%% @see prf_def/2
%% @end
%%--------------------------------------------------------------------
-spec prf_def(Block) -> Return when
      Block  :: binary(),
      Return :: pos_integer().

prf_def(Block) ->
    DefaultModulo = 64 * 1024 div 32,
    prf_def(Block, DefaultModulo).

%%--------------------------------------------------------------------
%% @doc quick and dirty pseudo determinist functions using modulo.
%% @end
%%--------------------------------------------------------------------
-spec prf_def(Block, Modulo) -> Return when
      Block  :: binary(),
      Modulo :: pos_integer(),
      Return :: pos_integer().

prf_def(<<Block:(32*8)/integer>>, Modulo) ->
    Block rem Modulo.

%%--------------------------------------------------------------------
%% @doc creates a chunk.
%% @end
%%--------------------------------------------------------------------
-spec chunk(Miner, Partition, Chunk) -> Return when
      Miner     :: binary(),
      Partition :: binary(),
      Chunk     :: binary(),
      Return    :: binary().

chunk(Miner, Partition, Chunk) ->
    packing(<<Miner/binary, Partition/binary, Chunk/binary>>).

%%--------------------------------------------------------------------
%% @doc creates a parallel chunk.
%% @end
%%--------------------------------------------------------------------
-spec chunk_par(Miner, PartitionsChunks) -> Return when
      Miner            :: binary(),
      PartitionsChunks :: [{Partition, Chunk}, ...],
      Partition        :: binary(),
      Chunk            :: binary(),
      Return           :: {ok, binary()}
                        | {error, null} .

chunk_par(<<>>, []) ->
    {error, null};
chunk_par(Miner, PartitionChunk) ->
    chunk_par(Miner, PartitionChunk, 0).

%%--------------------------------------------------------------------
%% @hidden
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec chunk_par(Miner, PartitionsChunks, Counter) -> Return when
      Miner            :: binary(),
      PartitionsChunks :: [{Partition, Chunk}, ...],
      Partition        :: binary(),
      Chunk            :: binary(),
      Counter          :: pos_integer(),
      Return           :: {ok, binary()}
                        | {error, null} .

chunk_par(_Miner, [], Counter) ->
    chunk_par_loop(Counter, []);
chunk_par(Miner, [{Partition, Chunk}|Rest], Counter) ->
    chunk_par_spawn(Miner, Partition, Chunk, Counter),
    chunk_par(Miner, Rest, Counter+1).

%%--------------------------------------------------------------------
%% @hidden
%% @doc custom chunk spawn
%% @end
%%--------------------------------------------------------------------
-spec chunk_par_spawn(Miner, Partition, Chunk, Counter) -> Return when
      Miner     :: binary(),
      Partition :: binary(),
      Chunk     :: binary(),
      Counter   :: pos_integer(),
      Return    :: pid().

chunk_par_spawn(Miner, Partition, Chunk, Counter) ->
    Target = self(),
    Args = [Counter, Miner, Partition, Chunk, Target],
    spawn_link(?MODULE, chunk_spawn, Args).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function.
%% @end
%%--------------------------------------------------------------------
-spec chunk_spawn(Counter, Miner, Partition, Chunk, Target) -> Return when
      Counter   :: pos_integer(),
      Miner     :: binary(),
      Partition :: binary(),
      Chunk     :: binary(),
      Target    :: pid() | atom(),
      Return    :: {ok, Message},
      Message   :: {Counter, Miner, Partition, Chunk, Result},
      Result    :: binary().

chunk_spawn(Counter, Miner, Partition, Chunk, Target) ->
    Result = chunk(Miner, Partition, Chunk),
    Message = {Counter, Miner, Partition, Chunk, Result},
    Target ! Message,
    {ok, Message}.

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function.
%% @end
%%--------------------------------------------------------------------
-spec chunk_par_loop(Counter, Buffer) -> Return when
      Counter :: pos_integer(),
      Buffer  :: binary(),
      Return  :: {ok, Result},
      Result  :: binary().

chunk_par_loop(0, Buffer) ->
    SortedBuffer = lists:sort(Buffer),
    Result = << <<R/binary>> || {_, _, _, _, R} <- SortedBuffer >>,
    {ok, Result};
chunk_par_loop(Counter, Buffer) ->
    receive
        Message = {_Counter, _Miner, _Partition, _Chunk, _Result} ->
            chunk_par_loop(Counter-1, [Message|Buffer])
    after
        10_000 ->
            throw({error, timeout})
    end.

%%--------------------------------------------------------------------
%% @doc returns a sequential hashing of the data given as argument.
%% @see sequential/2
%% @end
%%--------------------------------------------------------------------
-spec sequential(Data) -> Return when
      Data   :: binary(),
      Return :: binary().

sequential(Data) ->
    sequential(0, ?SEQUENTIAL_LOOP).

%%--------------------------------------------------------------------
%% @doc returns a sequential hashing of the data given as argument.
%%
%% Here a schema of the sequential hashing procedure.
%%
%% ```
%%                                  __________ 1_000_000 loop __
%%                                 |                            |
%%                                 |       +-----------------+  |
%%                                 |       |                 |  |
%%  ______      ________           |   ____V____             |  |
%% |      |    |        |          |  |         |            |  |
%% | data |--->| sha256 |---[hash]--->| sha256  |---[hash]---+  |
%% |______|    |________|          |  |_________|               |
%%                                 |_______|____________________|
%%                                         |
%%                                    _____V______
%%                                   |            |
%%                                   | final hash |
%%                                   |____________|
%%
%% '''
%%
%% == Examples ==
%%
%% ```
%% Hash = sequential(<<"my_data_to_hash">>, 1000).
%% '''
%%
%% @end
%%--------------------------------------------------------------------
-spec sequential(Data, Limit) -> Return when
      Data   :: binary(),
      Limit  :: pos_integer(),
      Return :: binary().

sequential(Data, Limit)
  when Limit > 0 ->
    State = crypto:hash_init(?HASH),
    NewState = crypto:hash_update(State, Data),
    sequential_loop(0, Limit, NewState).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. sequential hashing main function.
%% @end
%%--------------------------------------------------------------------
-spec sequential_loop(Counter, Limit, State) -> Return when
      Counter :: pos_integer(),
      Limit   :: pos_integer(),
      State   :: reference(),
      Return  :: binary().

sequential_loop(Counter, Limit, State)
  when Counter =:= Limit ->
    crypto:hash_final(State);
sequential_loop(Counter, Limit, State) ->
    StepHash = crypto:hash_final(State),
    NewState = crypto:hash_update(State, StepHash),
    sequential_loop(Counter+1, Limit, NewState).

sequential_test() ->
    [?assertEqual(<<   1,136,66,101, 172,100,123,29
                   , 233,80,187,174, 82,150,136,230
                   ,  243,66,225,61, 101,76,227,214
                   , 235,103,114,36, 181,25,192,180
                  >>, sequential(<<"test">>))
    ].

sequential_par(Data) ->
    DataLength = length(Data),
    Target = self(),
    Payload = [ {?MODULE, sequential_par_spawn, D, Target}
                || D <- Data ],
    sequential_par_loop(DataLength, 0, Payload, []).

sequential_par_spawn(Data, Target) ->
    Time = erlang:monotonic_time(),
    Result = sequential(Data),
    Target ! {?MODULE, sequential_par, Time, Result}.

sequential_par_loop(0, 0, [], Buffer) ->
    SortedBuffer = lists:sort(Buffer),
    Result = [ R || {_, R} <- SortedBuffer ],
    {ok, Result};
sequential_par_loop(DataLength, 0, List, Buffer) ->
    Jobs = 4,
    {SpawnList, Rest} = take(List, Jobs),
    LengthJobs = length(SpawnList),
    [ spawn_link(M, F, [D,T]) || {M, F, D, T} <- SpawnList ],
    sequential_par_loop_receive(DataLength, LengthJobs, Rest, Buffer);
sequential_par_loop(DataLength, Jobs, List, Buffer) ->
    sequential_par_loop_receive(DataLength, Jobs, List, Buffer).

sequential_par_loop_receive(DataLength, 0, Payloads, Buffer) ->
    sequential_par_loop(DataLength, 0, Payloads, Buffer);
sequential_par_loop_receive(DataLength, Jobs, Payloads, Buffer) ->
    receive
        _Message = {?MODULE, sequential_par, Time, Result} ->
            sequential_par_loop(DataLength-1, Jobs-1, Payloads, [{Time, Result}|Buffer])
    after
        60_000 ->
            ?LOG_ERROR("~p", [{?MODULE, ?FUNCTION_NAME, {error, timeout}}]),
            throw({error, timeout})
    end.

take(List, Amount) -> take(List, Amount, []).
take(T, 0, Buffer) -> {Buffer, T};
take([H|T], Amount, Buffer) -> take(T, Amount-1, Buffer ++ [H]);
take(T, Amount, Buffer)
  when length(T) < Amount ->
    {Buffer, T}.

%%--------------------------------------------------------------------
%% @doc packs a seed, final result will have 64kB size.
%%
%% @see packing/2
%% @end
%%--------------------------------------------------------------------
-spec packing(Seed) -> Return when
      Seed :: binary(),
      Return :: binary().

packing(Seed) ->
    packing(Seed, 64*1024).

%%--------------------------------------------------------------------
%% @doc packs a seed with custom size output.
%%
%% ```
%%  ______
%% |      |           __________ packing loop __
%% | seed |          |                          |
%% |______|          |     +----------------+   |
%%    |              |     |                |   |
%%  __V_____         |   __V_____           |   |
%% |        |        |  |        |          |   |
%% | sha256 |--[hash]-->| sha256 |--[hash]--+   |
%% |________|        |  |________|          |   |
%%                   |                      |   |
%%                   |______________________|___|
%%                                          |
%%                        ____ ____ _____ __V_
%%                       |    |    |     |    |
%%                       | S1 | S2 | ... | SN |
%%                       |____|____|_____|____|
%%
%%                      \______________________/
%%                         Limit Size in Bytes
%% '''
%%
%% == Examples ==
%%
%% ```
%% Pack = packing(<<MySeed>>, 64*1024).
%% '''
%%
%% @end
%%--------------------------------------------------------------------
-spec packing(Seed, ByteLimitSize) -> Return when
      Seed          :: binary(),
      ByteLimitSize :: pos_integer(),
      Return        :: binary().

packing(Seed, LimitSize)
  when LimitSize > 0 ->
    State = crypto:hash_init(?HASH),
    NewState = crypto:hash_update(State, Seed),
    NewSeed = crypto:hash_final(State),
    packing(NewSeed, <<>>, 0, LimitSize, NewState).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal packing function, main loop
%% @end
%%--------------------------------------------------------------------
-spec packing(Segment, Buffer, Counter, ByteLimitSize, State) -> Return when
      Segment       :: binary(),
      Buffer        :: binary(),
      Counter       :: pos_integer(),
      ByteLimitSize :: pos_integer(),
      State         :: reference(),
      Return        :: binary().

packing(_Segment, Buffer, Counter, Limit, State)
  when Counter >= Limit ->
    _ = crypto:hash_final(State),
    Buffer;
packing(Segment, Buffer, Counter, Limit, State) ->
    NewState = crypto:hash_update(State, Segment),
    NewSegment = crypto:hash_final(State),
    NewBuffer = <<Buffer/binary, NewSegment/binary>>,
    packing(NewSegment, NewBuffer, Counter+32, Limit, NewState).

packing_test() ->
    [?assertEqual(<< 159,134,208,129, 136,76,125,101
                   ,  154,47,234,160,  197,90,208,21
                   ,   163,191,79,27,   43,11,130,44
                   ,   209,93,108,21,   176,240,10,8
                  >>, packing(<<"test">>, 32))
    ].
