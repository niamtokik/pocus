# (P)roof (o)f (Cus)tody

Summary:

You'll need to implement a light version of a mechanism known as
"packing" which essentially encrypts chunks of data in Irys's chain
such that you can provide it's been uniquely stored. There is
practically zero documentation online for this but we've provided
granular steps below.

Steps:

1. Fill a 64KiB buffer with random entropy, this will represent data
   stored on the network. 64KiB denotes 64 Kilobytes that are 1024
   bytes in size, whereas KB indicates kilobytes that are 1000 Bytes
   in size.  KB is sometimes used interchangeably when referring to
   1024 byte kilobytes but KiB is precise in that it can only refer to
   1024 Bytes. 64KiB is 65535 bytes or 524280 bits.
    
2. Fill a 32B buffer with random entropy, this will represent a miner
   address on the network. 32B is 32 bytes and represent 256 bits.
        
3. Logically partition the 64KiB buffer from step 1 into 32B
   increments, for each 32B increment hash together the bytes of that
   increment with the “miner address” from step 2.  Then sequentially
   hash the resulting bytes 1,000,000 times using SHA-256. Once
   finished, write the bytes of the resulting hash sequence back to
   the same location in the 64KiB buffer that was used as the source
   of entropy. The description here varies somewhat from what is
   described in the take home steps, in that the mining address is
   only used as the head of the hash chain instead of included in each
   hash step. Feel free to use this method if it feels more
   appropriate.
            
4. This is a toy version of a packing mechanism suitable for a take
   home assignment. The packing (sequential hashing) should be done in
   C or Rust and be invoked using Erlang's Native Implemented Function
   (NIF) interface. The inputs should be the mining address from step
   2 and the 32B of random entropy from the specified offset in the
   64KiB buffer from Step 1. The 32B segments should be packed in
   parallel across multiple cores as much as possible.
                
5. Once the 64KiB buffer is fully “packed” with the miners address,
   you will calculate a simple proof of custody with the following
   mechanism.
                    
6. Fill a 32B buffer with random bytes, we’ll pretend this is a recent
   blockhash.
                        
7. Use it as entropy to a pseudo random (deterministic) function to
   select a starting 32B offset in the packed buffer. Hash the 32B at
   that offset together with the blockhash from step 6. The chunk is
   divided into 32B segments that the SHA-256 hashes are written
   to. Each segment exists at an offset starting with 0. Another way
   to think of offset is a specific offset into the "segment index"
   for the Chunk.
                            
8. Use the resulting hash from step 7 to repeat the process 10 more
   times, appending the hashes into a list. In production a merkle
   tree would be built out of this list of hashes, but for the purpose
   of a take home assignment we’ll use this list as the Proof of
   Custody. repeat the process from step 7, but instead of using the
   block hash to initialize the random function for the first step in
   the sequence, use the output of the operation in step 7 as the
   input to the next round.  This ensures that after the first step,
   computing the location of subsequent 9 steps requires the output of
   the previous step. This ensures that the sequence of hashes for the
   proof cannot be calculated in parallel.
                                
9. Finally write some erlang code to validate the proof of custody
   generated in step 8. Another miner should be able to start with an
   unpacked 64KiB buffer, use the blockhash (from step 6), miner
   address (from step step 2) and proof of custody (from Step 8). By
   packing the chunks of the Proof of Custody another miner should
   arrive at the same set of 10 hashes.

## Definitions

The tasks assigned were confusing, because of the terms used without
clear definition. This document is rewriting things based on
references found on internet or generated using OpenAI.

- **Hash Packing** (cryto-currency): **Hash packing** can be
  interpreted as a method where _multiple discrete data items are
  combined into a single composite data structure_ and then _hashed
  using a cryptographic hash function to produce a single output
  hash_. This process is commonly implemented using data structures
  like Merkle trees, as previously discussed. Here, the idea is to
  _aggregate data efficiently so that the integrity and authenticity
  of the entire dataset can be verified through a single hash_, the
  Merkle root. **Hash packing** is often used to create a compact and
  efficient representation of a large dataset for purposes like
  proving data integrity without needing to handle the entire
  dataset. **Hash Packing** output is a _single hash representing a
  set of data items_. In blockchain technology, transactions within a
  block can be hashed together using a Merkle tree, resulting in a
  single hash that effectively represents all transactions.
  
  - Combines many data items into one hash.
  
  - Utilizes structures like Merkle trees for efficient data
    aggregation and verification.
    
  - Commonly used to ensure data integrity and enable efficient
    verification processes (e.g., in blockchain transactions).

- **Sequential Hashing** (cryptography): **Sequential** Hashing refers
  to the process of _applying a hash function to data
  sequentially_. This could mean hashing data in a series where _the
  output of hashing one piece of data may be used as input for the
  next hashing operation, or continuously feeding data into a hash
  function as it is received_. **Sequential hashing** is typically
  used in scenarios where the order and continuity of data are
  critical, such as in securing a timeline of records or events. In a
  blockchain, each block's header contains the hash of the previous
  block's header, creating a sequential chain of block hashes. This
  chain secures the entire blockchain by making it resistant to
  tampering.
  
  - Data is processed in a sequence, one piece after another.
  
  - Each piece of data can be dependent on the hash of the previous
    piece, creating a chain of hashes.
    
  - Often used for creating hash chains or for situations where data
    needs to be timestamped or added in a specific order, such as in
    some forms of ledger or blockchain technology.

- **Proof of Custody** (blockchain/crypto-currency): **Proof of
  custody** in the context of cryptocurrency and blockchain technology
  generally refers to a mechanism or protocol by which a _participant_
  (often called a prover) _can demonstrate to others_ (called
  verifiers) _that they correctly possess certain data without
  actually revealing the data itself_. This is particularly important
  in scenarios where large amounts of data are stored off-chain or in
  decentralized storage systems, as in the case of some scaling
  solutions like sharding.

## Build

```sh
rebar3 compile
```

## Test

```sh
rebar3 ct
```

## Usage

```erlang
% create a new "plan"
{ok, R} = pocus:execute().

% check it
true = pocus:execute(R).
```

## Design

### SHA-256

This exercise has been solved using only
[`crypto`](https://www.erlang.org/doc/man/crypto.html#) module. A NIF
using [fast SHA-256
implementation](https://www.nayuki.io/page/fast-sha2-hashes-in-x86-assembly)
has been used, but this implementation does not support [SHA2
extensions](https://en.wikipedia.org/wiki/Intel_SHA_extensions), that
means this code is slower than
[OpenSSL](https://www.openssl.org/)/[LibreSSL](https://www.libressl.org/)
SHA-2 implementation. Others test have been conducted with:

 - [BearSSL](https://www.bearssl.org/)
 - [PolarSSL](https://polarssl.org/)
 - [WolfSSL](https://www.wolfssl.com/)
 
Those libraries offer barely the same speed over SHA-256. In
conclusion, only Erlang crypto module implementation has been
retained, but the NIF has been kept as example, here how to use it.

```sh
# build pocus_nif.so and copy it into priv
cd c_src
# gmake on openbsd.
make
cp pocus_nif.so ../priv
cd ..

# execute rebar3 shell
rebar3 shell
```

```erlang
% start playing with the implementation
pocus_nif:sha256(<<"test">>).
```

This implementation is ~10x slower than crypto module using
OpenSSL/LibreSSL.

### Parallel/Distributed Computing

To improve the computation on some part of the code, in particular in
chunk generation part, a small jobs manager has been created, dividing
the computation in dedicated processus, spawned on demand. A more
classical method with a pool of worker already spawned could have been
created though.

### Future Work

The current model is not really scalable and flexible. A
[`pocus_sequential`](src/pocus_sequential.erl) module defined as
`gen_server` would have probably better. When started a process would
then keep the state of the computation and all event would have been
treated as step to produce the final hash. A tested PoC has been also
added in this exercise.
