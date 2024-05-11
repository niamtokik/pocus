# Assignment

The tasks assigned were confusing, because of the terms used without
clear definition. This document is rewriting things based on
references found on internet or generated using OpenAI.

## Definitions

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


