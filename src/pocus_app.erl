%%%-------------------------------------------------------------------
%% @doc pocus public API
%% @end
%%%-------------------------------------------------------------------

-module(pocus_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    pocus_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
