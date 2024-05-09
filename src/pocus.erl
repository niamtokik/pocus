%%%===================================================================
%%% @doc
%%%
%%% ```
%%%    data (64kB)             miner (32B)
%%%  /____ _____ _____       /____
%%% |     |     |     |     |     |
%%% | 32B | 32B | ... |     | 32B |
%%% |_____|_____|_____|     |_____|
%%%    |                       |
%%%    |                       |
%%%    +-----------------------+
%%%    |
%%%    |
%%%  (sha256)
%%%    |
%%%  __|__ _____ _____
%%% |     |     |     |
%%% | 32B | 32B | ... |---+
%%% |_____|_____|_____|   |
%%%    ^                  (sha256 * 1_000_000)
%%%    |                  |
%%%    +------------------+
%%%
%%%
%%%
%%% '''
%%%
%%% @end
%%%===================================================================
-module(pocus).
-compile(export_all).
-include("pocus.hrl").
-include("pocus_types.hrl").
-include_lib("kernel/include/logger.hrl").
-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% @doc generate a random network address.
%% @end
%%--------------------------------------------------------------------
-spec prng(ByteSize) -> Return when
      ByteSize :: pos_integer(),
      Return :: binary().

prng(ByteSize) -> 
    crypto:strong_rand_bytes(ByteSize).

%%--------------------------------------------------------------------
%% @doc generate a random network address.
%% @end
%%--------------------------------------------------------------------
-spec network_address() -> network_address().

network_address() -> prng(?DATA_SIZE).

%%--------------------------------------------------------------------
%% @doc generates a random miner address.
%% @end
%%--------------------------------------------------------------------
-spec miner_address() -> miner_address().

miner_address() -> prng(?MINER_SIZE).

%%--------------------------------------------------------------------
%% @doc produces the initial seed hash.
%% @end
%%--------------------------------------------------------------------
-spec segment_seed_hash(MiningAddress, PartitionId, ChunkId) -> Return when
      MiningAddress :: binary(),
      PartitionId :: binary(),
      ChunkId :: pos_integer(),
      Return :: binary().

segment_seed_hash(MiningAddress, PartitionId, ChunkId) ->
    Starter = << MiningAddress/binary
               , PartitionId:32/integer
               , ChunkId:32/integer >>,
    crypto:hash(?HASH, Starter).

%%--------------------------------------------------------------------
%% @doc produces a new segment
%% @end
%%--------------------------------------------------------------------
-spec segment(Segment) -> Segment when
      Segment :: binary().
      
segment(Segment) ->
    crypto:hash(?HASH, Segment).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec chunk(MiningAddress, PartitionId, ChunkId) -> Return when
      MiningAddress :: binary(),
      PartitionId :: integer(),
      ChunkId :: integer(),
      Return :: [binary()].
      
chunk(MiningAddress, PartitionId, ChunkId) ->
    SeedHash = segment_seed_hash(MiningAddress, PartitionId, ChunkId),
    segments(SeedHash).

%%--------------------------------------------------------------------
%% @doc produces a binary
%% @end
%%--------------------------------------------------------------------
segments_as_binary(Segment) -> 
    << <<X/binary>> || X <- segments(Segment) >>.

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
segments(Segment)
  when byte_size(Segment) =:= ?SEGMENT_SIZE -> 
    ByteLimit = ?CHUNK_SIZE div ?SEGMENT_SIZE,
    segments(Segment, [], ByteLimit).

segments(_, Buffer, 0) -> Buffer;
segments(Segment, Buffer, ByteLimit) ->
    NewSegment = segment(Segment),
    NewBuffer = lists:append(Buffer, [NewSegment]),
    segments(NewSegment, NewBuffer, ByteLimit-?SEGMENT_SIZE).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
sequential2() ->
    Network = network_address(),
    Miner = miner_address(),
    sequential2(Network, Miner).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
sequential2(Network, Miner) ->
    Chunks = chunk2(Network, Miner),
    ChunkHashes = [ hash_round(Chunk) || Chunk <- Chunks ],
    << <<Chunk/binary>> || Chunk <- ChunkHashes >>.

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
chunk2(Data, Miner) ->
    chunk2(Data, Miner, 32, []).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
chunk2(<<>>, _, _, Buffer) -> lists:reverse(Buffer);
chunk2(<<Chunk:32/binary, Rest/binary>>, Miner, Size, Buffer) ->
    Hash = crypto:hash(?HASH, <<Chunk/binary, Miner/binary>>),
    [Hash|Buffer].

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
hash_round(Hash) ->
    hash_round(Hash, 1_000_000).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
hash_round(Hash, 0) -> Hash;    
hash_round(Hash, Counter) ->
    Result = crypto:hash(?HASH, Hash),
    hash_round(Result, Counter-1).
                                          

    
    

