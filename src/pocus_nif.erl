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
%%% @copyright Mathieu Kerjouan
%%% @doc
%%% @end
%%%===================================================================
-module(pocus_nif).
-export([init/0]).
-export([sha256/1, sha256_sequential/3]).
-nifs([sha256/1, sha256_sequential/3]).
-on_load(init/0).

init() -> init("pocus_nif").

init(Path) ->
    PrivDir = application:get_env(pocus, lib_path, priv_dir()),
    Lib = filename:join(PrivDir, Path),
    ok = erlang:load_nif(Lib, 0).

priv_dir() ->
    case code:priv_dir(cozo) of
        {error, bad_name} ->
            case code:which(?MODULE) of
                FN when is_list(FN) ->
                    filename:join([filename:dirname(FN), "..", "priv"]);
                _ ->
                    "../priv"
            end;
        Val ->
            Val
    end.

sha256(Data) ->
    exit(nif_library_not_loaded).

sha256_sequential(Data, Seed, Blocksize) ->
    exit(nif_library_not_loaded).
