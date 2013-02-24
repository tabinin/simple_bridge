%% vim: ts=4 sw=4 et
% Simple Bridge Cowboy
% Copyright (c) 2012 Jesse Gumm
% See MIT-LICENSE for licensing information.

-module (cowboy_request_bridge).
-behaviour (simple_bridge_request).
-include_lib ("simple_bridge.hrl").
-include_lib("common_test/include/ct.hrl").

-export ([
    init/1,
    protocol/1, request_method/1, path/1, uri/1,
    peer_ip/1, peer_port/1,
    headers/1, cookies/1,
    query_params/1, post_params/1, request_body/1,
    socket/1, recv_from_socket/3
]).

-define(GET,_RequestCache=#request_cache{request=Req}=cowboy_request_server:get(ReqKey)).
-define(PUT,cowboy_request_server:set(ReqKey,NewRequestCache)).

new_key() ->
    {cowboy_bridge,now()}.

init({Req,DocRoot}) ->
    ct:log("-> cowboy req. bridge, init ~p", [erlang:get_stacktrace()]),
    ReqKey = new_key(),
    NewRequestCache = #request_cache{
        body=not_loaded,
        request=Req,
        docroot=DocRoot
    },
    ?PUT,
    ReqKey.

protocol(_ReqKey) -> undefined.

request_method(ReqKey) ->
    ct:log("-> cowboy req. bridge, req. method ~p", [erlang:get_stacktrace()]),
    ?GET,
    {Method, Req} = cowboy_req:method(Req),
    ct:log("-> after cowboy req. bridge, req. method ~p", [Method]),
    Method.

path(ReqKey) ->
    ?GET,
    ct:log("-> cowboy req. bridge, path ~p, ~p", [ReqKey, erlang:get_stacktrace()]),
    {Path, Req} = cowboy_req:path(Req),
    ct:log("-> after cowboy req. bridge, path ~p, ~p", [Path, erlang:get_stacktrace()]),
    Path1 = case Path of
        <<"/">> -> "/";
        _ -> "/" ++ b2l(filename:join(Path)) %Mochweb returns path as /path and Cowboy does not
    end,
    %% Path1 = b2l(filename:join(Path)), %Mochweb returns path as /path and Cowboy does not
    ct:log("-> Path cowboy req. bridge, path ~p, ~p", [Path1]),
    Path1.


uri(ReqKey) ->
    ?GET,
    {RawPath, Req} = case cowboy_http_req:raw_path(Req) of
     undefined -> {undefined, ok};
     {P, R} -> {P, R}
     end,
    b2l(RawPath).

peer_ip(ReqKey) ->
    ?GET,
    {{IP, _Port}, NewReq} = cowboy_http_req:peer(Req),
    NewRequestCache = _RequestCache#request_cache{request=NewReq},
    ?PUT,
    IP.

peer_port(ReqKey) ->
    ?GET,
    {Port, NewReq} = cowboy_http_req:port(Req),
    NewRequestCache = _RequestCache#request_cache{request=NewReq},
    ?PUT,
    Port.

headers(ReqKey) ->
    ct:log("-> cowboy req. bridge, headers ~p", [erlang:get_stacktrace()]),
    ?GET,
    {Headers,Req} = cowboy_req:headers(Req),
    ct:log("-> after cowboy req. bridge, headers ~p", [Headers]),
    [{simple_bridge_util:atomize_header(Header),b2l(Val)} || {Header,Val} <- Headers].

cookies(ReqKey) ->
    ?GET,
    ct:log("-> cowboy req. bridge, cookies ~p, ~p", [ReqKey, erlang:get_stacktrace()]),
    {Cookies, NewReq} = cowboy_req:cookies(Req),
    ct:log("-> after cowboy req. bridge, cookies ~p, ~p", [Cookies, erlang:get_stacktrace()]),
    NewRequestCache = _RequestCache#request_cache{request=NewReq},
    ?PUT,
    [{b2l(K),b2l(V)} || {K,V} <- Cookies].

query_params(ReqKey) ->
    ?GET,
    ct:log("-> cowboy req. bridge, query_params ~p, ~p", [ ReqKey, erlang:get_stacktrace()]),
    {QsVals, NewReq} = cowboy_req:qs_vals(Req),
    ct:log("-> after cowboy req. bridge, query_params ~p", [QsVals]),
    NewRequestCache = _RequestCache#request_cache{request=NewReq},
    ?PUT,
    [{b2l(K),b2l(V)} || {K,V} <- QsVals].



post_params(ReqKey) ->
    Body = request_body(ReqKey,binary),
    BodyQs = parse_qs(Body),
    [{b2l(K),b2l(V)} || {K,V} <- BodyQs].

request_body(ReqKey) ->
    request_body(ReqKey,string).

request_body(ReqKey,binary) ->
    ?GET,
     %% We cache the body here because we can't request the body twice in cowboy or it'll crash
    {Body,NewReq} = case _RequestCache#request_cache.body of
        not_loaded ->
            {ok, B, R} = cowboy_http_req:body(Req),
            {B,R};
        B -> {B,Req}
    end,
    NewRequestCache = _RequestCache#request_cache {
        body=Body,
        request=NewReq
    },
    ?PUT,
    Body;
request_body(ReqKey,string) ->
    b2l(request_body(ReqKey,binary)).


socket(ReqKey) ->
    ?GET,
    {ok, _Transport, Socket} = cowboy_http_req:transport(Req),
    Socket.

%% TODO: Cowboy's stream_body doesn't support customizable Length and Timeout
recv_from_socket(_Length, _Timeout, ReqKey) ->
    ?GET,
    %cowboy_http_req:init_stream(
    case cowboy_http_req:stream_body(Req) of
        {ok, Data, NewReq} ->
            NewRequestCache = _RequestCache#request_cache{request=NewReq},
            ?PUT,
            Data;
        {done, NewReq} ->
            NewRequestCache = _RequestCache#request_cache{request=NewReq},
            ?PUT,
            <<"">>;
        {error, Reason} ->
            exit({error, Reason}) %% exit(normal) instead?
    end.



%% parse_qs, borrowed from Cowboy by Loic Hugian :)
parse_qs(<<>>) ->
    [];
parse_qs(Qs) ->
    URLDecode = fun cowboy_http:urldecode/1,
    Tokens = binary:split(Qs, <<"&">>, [global, trim]),
    [case binary:split(Token, <<"=">>) of
        [Token] -> {URLDecode(Token), true};
        [Name, Value] -> {URLDecode(Name), URLDecode(Value)}
    end || Token <- Tokens].


b2l(B) when is_binary(B) ->
    binary_to_list(B);
b2l(B) ->
    B.

