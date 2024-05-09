1. Fill a 64KiB buffer with random entropy, this will represent data
   stored on the network.

```erlang
NetworkData = crypto:strong_rand_bytes(65536).
```

2. Fill a 32B buffer with random entropy, this will represent a miner
   address on the network.

```erlang
MinerAddress = crypto:strong_rand_bytes(32).
```

3. prng

3.1. Logically partition the 64KiB buffer from step 1 into 32B
increments.

```erlang
Increments = [ <<Increment>> || <<Increment:32/binary>> <= NetworkData ].
```

3.2. for each 32B increment hash together the bytes of that increment
with the “miner address” from step 2.

```erlang
HashedIncrements = [ crypto:hash(sha256, <<Increment/binary, MinerAddress/binary>>) || Increment <- Increments ].
```

3.3. Then sequentially hash the resulting bytes 1,000,000 times using SHA-256

```erlang
HashedIncrements = [ 
```

3.4. Once finished, write the bytes of the resulting hash sequence
back to the same location in the 64KiB buffer that was used as the
source of entropy.

```erlang
```

4. packing

4.1. The inputs should be the mining address from step 2 and the 32B
of random entropy from the specified offset in the 64KiB buffer from
Step 1. The 32B segments should be packed in parallel across multiple
cores as much as possible.

```erlang
```
