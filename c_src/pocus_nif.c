/* Copyright (c) 2024 Mathieu Kerjouan
 *
 * Permission to use, copy, modify, and distribute this software for
 * any purpose with or without fee is hereby granted, provided that
 * the above copyright notice and this permission notice appear in all
 * copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
 * WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * This NIF implements Nayuki Fast SHA256 Hash
 * functions. Unfortunately, this code is less performant than crypto
 * module and all OpenSSL/LibreSSL optimization (in part because the
 * implementation does not use CPU special features)
 *
 */

#include <ei.h>
#include <erl_nif.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "sha256.h"

#define BLOCK_LEN 64  // In bytes
#define STATE_LEN 8  // In words

static ERL_NIF_TERM pocus_sha256(ErlNifEnv *, int, const ERL_NIF_TERM *);
// static ERL_NIF_TERM pocus_sha256_asm(ErlNifEnv *, int, const ERL_NIF_TERM *);
void sha256_hash(const uint8_t[], size_t, uint32_t hash[static STATE_LEN]);

/*
 * from sha256_test.c file.
 */
void
sha256_hash(const uint8_t message[], size_t len, uint32_t hash[static STATE_LEN]) {
	hash[0] = UINT32_C(0x6A09E667);
	hash[1] = UINT32_C(0xBB67AE85);
	hash[2] = UINT32_C(0x3C6EF372);
	hash[3] = UINT32_C(0xA54FF53A);
	hash[4] = UINT32_C(0x510E527F);
	hash[5] = UINT32_C(0x9B05688C);
	hash[6] = UINT32_C(0x1F83D9AB);
	hash[7] = UINT32_C(0x5BE0CD19);
	
	#define LENGTH_SIZE 8  // In bytes
	
	size_t off;
	for (off = 0; len - off >= BLOCK_LEN; off += BLOCK_LEN)
		sha256_compress(&message[off], hash);
	
	uint8_t block[BLOCK_LEN] = {0};
	size_t rem = len - off;
	if (rem > 0)
		memcpy(block, &message[off], rem);
	
	block[rem] = 0x80;
	rem++;
	if (BLOCK_LEN - rem < LENGTH_SIZE) {
		sha256_compress(block, hash);
		memset(block, 0, sizeof(block));
	}
	
	block[BLOCK_LEN - 1] = (uint8_t)((len & 0x1FU) << 3);
	len >>= 5;
	for (int i = 1; i < LENGTH_SIZE; i++, len >>= 8)
		block[BLOCK_LEN - 1 - i] = (uint8_t)(len & 0xFFU);
	sha256_compress(block, hash);
	
	#undef LENGTH_SIZE
}

/*
 * Interface to sha256_hash function.
 */
static ERL_NIF_TERM
pocus_sha256(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  // only one argument is allowed
  if (argc != 1)
    return enif_make_badarg(env);

  // ensure argv[0] is a binary
  if (enif_is_binary(env, argv[0]) != true)
    return enif_make_badarg(env);

  // Create a new binary when argv[0] is a bin
  ErlNifBinary bin;
  if (enif_inspect_binary(env, argv[0], &bin) == false)
    return enif_make_badarg(env);

  // hash data and store results in hash variable
  uint32_t hash[STATE_LEN] = {0};
  sha256_hash(bin.data, bin.size, hash);

  // initialize the final hash buffer
  ErlNifBinary final_hash;
  enif_alloc_binary(256, &final_hash);
  bzero(final_hash.data, 256);

  // convert hash string to binary term
  uint32_t *p = (uint32_t *) final_hash.data;
  for (int i=0; i<8; i++) {
    p[i] = __builtin_bswap32(hash[i]);
  }

  // return final hash
  return enif_make_binary(env, &final_hash);
}

// sha256_sequential(Data, Seed, Blocksize).
static ERL_NIF_TERM
pocus_sha256_sequential(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  // only one argument is allowed
  if (argc != 3)
    return enif_make_badarg(env);

  // Data arg: ensure argv[0] is a binary
  if (enif_is_binary(env, argv[0]) != true)
    return enif_make_badarg(env);

  // Seed arg: ensure argv[1] is a binary
  if (enif_is_binary(env, argv[1]) != true)
    return enif_make_badarg(env);

  // ensure argv[2] is an integer
  unsigned int block_size = 0;
  if (enif_get_uint(env, argv[2], &block_size) != true)
    return enif_make_badarg(env);
  
  return enif_make_int(env, block_size);
}

/*
 *
 */
static ErlNifFunc nif_funcs[] = {
  {"sha256", 1, pocus_sha256},
  {"sha256_sequential", 3, pocus_sha256_sequential}
};

/*
 *
 */
ERL_NIF_INIT(pocus_nif, nif_funcs, NULL, NULL, NULL, NULL);
  


