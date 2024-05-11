######################################################################
# Copyright (c) 2024 Mathieu Kerjouan
#
# Permission to use, copy, modify, and distribute this software for
# any purpose with or without fee is hereby granted, provided that the
# above copyright notice and this permission notice appear in all
# copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA
# OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# -------------------------------------------------------------------
#
# GNU Makefile only support openbsd and linux distribution
# 
######################################################################
SYSTEM = $(shell uname -s)
CCFLAGS = -O1 -march=native -finline-functions -Wall -Werror -Wmissing-prototypes -fPIC

# Usually, with default package manager, Linux distributions are
# storing Erlang files into /usr/lib
ifeq ($(SYSTEM),Linux)
  CCFLAGS += -I /usr/lib/erlang/usr/include 
  CCFLAGS += -L /usr/lib/erlang/usr/lib
endif

# OpenBSD uses Erlang special version in /usr/local/lib/erlang*
ifeq ($(SYSTEM),OpenBSD)
  ERL_VERSION ?= 25
  CCFLAGS += -I /usr/local/lib/erlang$(ERL_VERSION)/usr/include 
  CCFLAGS += -L /usr/local/lib/erlang$(ERL_VERSION)/usr/lib
endif

# main command
CC = cc $(CCFLAGS) -lei

all: pocus_nif.so

# build sha256 test suite
test: sha256_test sha256_test_asm
	./sha256_test
	./sha256_test_asm

# clean files
clean:
	-rm pocus_nif.so pocus_nif_asm.so
	-rm sha256_test sha256_test_asm

# default NIF using C code
pocus_nif.so: 
	$(CC) -shared pocus_nif.c sha256.c -o $@

# NIF using assembly
pocus_nif_asm.so:
	$(CC) -shared pocus_nif.c sha256_x86_64.S -o $@

# C code test
sha256_test:
	$(CC) sha256_test.c sha256.c -o $@

# ASM code test
sha256_test_asm:
	$(CC) sha256_test.c sha256_x86_64.S -o $@

