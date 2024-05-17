# (P)roof (o)f (Cus)tody

`pocus` project aims to offer a flexible way to produce cryptographic
hashes using fast and distributed computations. This project should
offer a framework providing a high level abstraction for different
kind of methods, mechanisms and strategies used in cryptography.

Keywords: Merkle Trees; Hash Chains; Sequential hashing; Hash Packing;
Bloom Filters; Consistent Hashing; Hash Pointers; Cuckoo Hashing;
Perfect Hashing; Hash Graphs; Salted Hashing; Hash Tables; Hash-based
Encryption; Prefix Hash Tree; Sparse Merkle Trees; Hash-based
Signatures; Incremental Hashing; Adaptive Hashing; Deduplication
Hashing; Hash-Driven Key Stretching; Homomorphic Hashing;
Deterministic Hashing; Trapdoor Hash Functions; SimHash; Keyed Hash
Functions; Hash Tree Roots; Hash Aggregation; Hash Rings; Composite
Hash Functions.

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

## Objectives

 - Academic and educational purpose
  - [ ] Documentation
  - [ ] Test
  - [ ] Notes and References

 - [ ] High Level Interfaces (methods)
   - [ ] Sequential Hashing
   - [ ] Hash Packing
   - [ ] SimHash

 - [ ] Low Level Interfaces
   - [ ] BearSSL
   - [ ] PolarSSL
   - [ ] WolfSSL
   - [ ] Pure C
   - [ ] Pure Assembly (x86-64/risc-v)

 - [ ] Cryptographic Hash Functions Support
   - [ ] md4
   - [ ] md5
   - [ ] md6
   - [ ] sha1
   - [ ] sha-2 family
   - [ ] sha-3 family
   - [ ] blake family
   - [ ] ripemd160
   - [ ] skein
   - [ ] whirlpool
   - [ ] gost

 - [ ] Non-Cryptographic Hash Functions Support
   - [ ] Fast-Hash
   - [ ] Bernstein Hash
   - [ ] GxHash
   - [ ] pHash
   - [ ] dHash

## History

This project has been created at first as an assignment for an
interview. Unfortunately during the implementation, I found definition
on certain terms were not clear. Even more, no high level
implementations in Erlang were available.

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

## References and Resources

[Choosing Best Hashing Strategies and Hash
Functions](https://gdeepak.com/pubs/choosing%20best%20hashing%20strategies%20and%20hash%20functions.pdf)
by Mahima Singh and Deepak Garg

[Parallel cryptographic hashing: Developments in the last 25
years](https://www.tandfonline.com/doi/abs/10.1080/01611194.2019.1609130)
by Neha Kishore and Priya Raina

[Cipher and Hash Function Design Strategies based on linear and
differential
cryptanalysis](https://cs.ru.nl/~joan/papers/JDA_Thesis_1995.pdf) by
Joan Daemen

[Analysis and Design of Cryptographic Hash
Functions](https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=f3899323a7b6d060ce720e6cb6e97c390164ef63)
by Bart PRENEEL

### Sequential Hashing

[Sequential Hashing with Minimum
Padding](https://www.mdpi.com/2410-387X/2/2/11/pdf) by Shoichi Hirose

[Suffcient conditions for sound tree and sequential hashing
modes](https://eprint.iacr.org/2009/210.pdf) by Guido Bertoni, Joan
Daemen, Michaël Peeters, and Gilles Van Assche

[New Methodes for Sequential Hashing with
Supertrace](https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=57d948a0782799c13148fe05882020687ad87789)
by Jürgen Eckerle and Thomas Lais

[Sakura: a ﬂexible coding for tree
hashing](https://eprint.iacr.org/2013/231.pdf) by Guido Bertoni, Joan
Daemen, Michaël Peeters, and Gilles Van Assche

[Block-Cipher-Based Tree
Hashing](https://eprint.iacr.org/2022/283.pdf) by Aldo Gunsing

### SimHash

[SimHash: Hash-based Similarity
Detection](http://www.webrankinfo.com/dossiers/wp-content/uploads/simhash.pdf)
by Caitlin Sadowski and Greg Levin
