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
%%%===================================================================
-module(pocus_sup).
-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
init([]) ->
    {ok, {supervisor_flags(), children()}}.

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
supervisor_flags() ->
    # { strategy => one_for_one
      , intensity => 0
      , period => 1
      }.

%%--------------------------------------------------------------------
%%
%%--------------------------------------------------------------------
children() ->
    [].
