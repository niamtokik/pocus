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

## Build

```sh
rebar3 compile
```

## Design

```

```
