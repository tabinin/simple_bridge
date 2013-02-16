%% Feel free to use, reuse and abuse the code in this file.

-module(nitrogen_handler).
-behaviour(cowboy_http_handler).
-export([init/3, handle/2, terminate/2]).
-include_lib("common_test/include/ct.hrl").
-record(state, {headers, body, root}).

init({_Transport, http}, Req, Opts) ->
    {ok, Req, #state{}}.

handle(Req, State) ->
    RequestBridge = simple_bridge:make_request(cowboy_request_bridge, {Req, "priv_dir"}),
    ResponseBridge = simple_bridge:make_response(cowboy_response_bridge, RequestBridge),
    %% Establishes the context with the Request and Response Bridges
    nitrogen:init_request(RequestBridge, ResponseBridge),
    {ok, Req2} = nitrogen:run(),
    ct:log("-> req, ~p", [Req2]),
    %%{ok, Req2} = cowboy_http_req:reply(200, Headers, Body, Req),
    {ok, Req2, State}.

terminate(_Req, _State) ->
	ok.