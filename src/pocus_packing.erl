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
%%% @copyright 2024 (c) Mathieu Kerjouan
%%% @doc A generic hash packing implementation.
%%%
%%% The goal of this module is to offer a generic implement of hach
%%% packing algorithm, with a support of different hash
%%% functions. Here a schema of the procedure.
%%%
%%%
%%% ```
%%%   ______  \
%%%  |      |  | A seed is made of mining address as binary term
%%%  | seed |  | (mandatory) and can also use a partition id and
%%%  |______|  | chunk id (optional).
%%%     ||    /
%%%    _||_         ____  \
%%%   _\__/_       |    |  |
%%%  |      |      |    |  |
%%%  | hash |----> | S1 |  |
%%%  |______|      |    |  |
%%%     ||         |    |  |
%%%    _||_        |____|  |
%%%   _\__/_       |    |  | A chunk, where S1, S2, SN are segments
%%%  |      |      |    |  | of the same size.
%%%  | hash |----> | S2 |  |
%%%  |______|      |    |  |
%%%     ||         |    |  |
%%%    _||_        |____|  |
%%%   _\__/_       |    |  |
%%%  |      |      |    |  |
%%%  | hash |----> | SN |  |
%%%  |______|      |    |  |
%%%                |....|  |
%%%                       /
%%%
%%% '''
%%%
%%% @end
%%%===================================================================
-module(pocus_packing).
-export([create/1, create/2, create_multi/1]).
-include("pocus.hrl").
-include_lib("kernel/include/logger.hrl").

%%--------------------------------------------------------------------
%% @doc creates a new chunk of hashed segments.
%%
%% @see create/2
%% @end
%%--------------------------------------------------------------------
-spec create(MiningAddress) -> Return when
      MiningAddress :: binary(),
      Return :: binary().

create(MiningAddress) ->
    create(MiningAddress, #{}).

%%--------------------------------------------------------------------
%% @doc Creates a new chunk of hashed segments.
%%
%% The seed is generated using a `Mining Address' (mandatory) as first
%% argument. a `Partition Id' and a `Chunk Id' can also be set in
%% options.
%%
%% By default, this function is using sha256 with a segment size of 32
%% bytes, and a chunk size of 65535 bytes. These elements generate a
%% state, useful in case of debugging session.
%%
%% == Examples ==
%%
%% The following example will result in a list of chained hashes,
%% using `<<"MiningAddress">>' binary as Mining address, concatened
%% with a chunk id and partition id both set to `1' and encoded as 32
%% bits integer.
%%
%% ```
%% Result = create(<<"MiningAddress">>, #{ chunk_id => <<1:32>>
%%                                       , partition_id => <<1:32>>
%%                                       }).
%% '''
%%
%% @end
%%--------------------------------------------------------------------
-spec create(MiningAddress, Opts) -> Return when
      MiningAddress :: binary(),
      Opts :: map(),
      Return :: binary().

create(MiningAddress, Opts) ->
    % Get variables states from options.
    PartitionId = maps:get(partition_id, Opts, <<>>),
    ChunkId = maps:get(chunk_id, Opts, <<>>),
    ChunkSize = maps:get(chunk_size, Opts, ?CHUNK_SIZE),
    SegmentSize = maps:get(segment_size, Opts, ?SEGMENT_SIZE),
    Hash = maps:get(hash, Opts, ?HASH),
    HashInfo = maps:get(hash_info, Opts, #{block_size => 64, size => 32, type => 672}),

    % Create the seed using Mining address, partition id and chunk id.
    Seed = <<MiningAddress/binary, PartitionId/binary, ChunkId/binary>>,
    SeedHash = crypto:hash(sha256, Seed),

    % Create the final state data-structure containing all information
    % to create the sequential hashing scheme.
    State = #{ mining_address => MiningAddress
             , partition_id => PartitionId
             , chunk_id => ChunkId
             , chunk_size => ChunkSize
             , segment_size => SegmentSize
             , hash => Hash
             , hash_info => HashInfo
             , seed => Seed
             , seed_hash => SeedHash
             , counter => 0
             },
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, ?FUNCTION_ARITY, [MiningAddress, PartitionId, ChunkId]}]),
    create2(SeedHash, [], State).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. main loop to create a chunk.
%%
%% see create/2
%% @end
%%--------------------------------------------------------------------
-spec create2(Segment, Buffer, State) -> Return when
      Segment :: binary(),
      Buffer :: [binary()],
      State :: map(),
      Return :: binary().

create2(Segment, Buffer, State = #{chunk_size := ChunkSize, counter := Counter})
  when Counter >= ChunkSize ->
    ?LOG_DEBUG("~p", [{?MODULE, ?FUNCTION_NAME, ?FUNCTION_ARITY, [Segment, Buffer, State]}]),
    lists:reverse(Buffer);
create2(Segment, Buffer, State = #{counter := Counter, hash_info := #{size := HashSize}}) ->
    NewSegment = crypto:hash(?HASH, Segment),
    create2(NewSegment, [NewSegment|Buffer], State#{counter => Counter+HashSize}).

%%--------------------------------------------------------------------
%% @doc parallel packing creation.
%%
%% A parallel way to create hash packing. This function is using
%% linked processes to compute/create packing in distributed way. It
%% returns an un-ordered list of result. Developers are in charge of
%% tagging each message with a custom id.
%%
%% == Examples ==
%%
%% ```
%% Return = create_multi([{custom_id, <<"miningaddress">>, #{}]).
%% '''
%%
%% @end
%%--------------------------------------------------------------------
-spec create_multi(Multi) -> Return when
      Multi         :: [Single],
      Single        :: {Id, MiningAddress, Opts},
      Id            :: term(),
      MiningAddress :: binary(),
      Opts          :: map(),
      Segment       :: [{Id, MiningAddress, Opts, Result}],
      Result        :: binary(),
      Return        :: {ok, Segment} | {error, term()}.

create_multi(Multi) ->
    % set the caller pid
    Target = self(),

    % spawn linerarilly all tasks
    [ spawn_link(fun() -> spawn_multi(Target, Id, MiningAddress, Opts) end)
      || {Id, MiningAddress, Opts} <- Multi ],

    % wait for messages.
    create_multi2(Multi, length(Multi), []).

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. receive messages from spawn_multi/4
%% processes
%%
%% @end
%%--------------------------------------------------------------------
create_multi2(_Multi, 0, Buffer) ->
    % we received all required messages, we can sort the buffer and
    % return it
    {ok, lists:sort(Buffer)};
create_multi2(Multi, Length, Buffer) ->
    % wait for all messages or die
    receive
        {?MODULE, Id, MiningAddress, Opts, Result} ->
            NewBuffer = [{Id, MiningAddress, Opts, Result}|Buffer],
            create_multi2(Multi, Length-1, NewBuffer)
    after
        10000 ->
            {error, timeout}
    end.

%%--------------------------------------------------------------------
%% @hidden
%% @doc internal function. main process used to create packing.
%% @end
%%--------------------------------------------------------------------
-spec spawn_multi(Target, Id, MiningAddress, Opts) -> Return when
      Target        :: pid() | atom(),
      Id            :: term(),
      MiningAddress :: binary(),
      Opts          :: map(),
      Message       :: {?MODULE, Id, MiningAddress, Opts, Result},
      Result        :: binary(),
      Return        :: {ok, Message}.

spawn_multi(Target, Id, MiningAddress, Opts) ->
    Result = create(MiningAddress, Opts),
    Message = {?MODULE, Id, MiningAddress, Opts, Result},
    Target ! Message,
    {ok, Message}.
