-module(demo).

-export([start/0, open/2, recv/4, close/3]).

-record(session_state, {}).

start() ->
    ok = application:start(sasl),
    ok = application:start(crypto),
    ok = application:start(public_key),
    ok = application:start(ssl),
    ok = application:start(ranch),
    ok = application:start(cowboy),
    ok = application:start(socketio),

    Dispatch = [
                {'_', [
                       {[<<"socket.io">>, <<"1">>, '...'], socketio_handler, [socketio_session:configure([{heartbeat, 5000},
                                                                                                          {heartbeat_timeout, 30000},
                                                                                                          {session_timeout, 30000},
                                                                                                          {callback, ?MODULE},
                                                                                                          {protocol, socketio_data_protocol}])]},
                       {['...'], cowboy_static, [
                                                 {directory, <<"./priv">>},
                                                 {mimetypes, [
                                                              {<<".html">>, [<<"text/html">>]},
                                                              {<<".css">>, [<<"text/css">>]},
                                                              {<<".js">>, [<<"application/javascript">>]}]}
                                                ]}
                      ]}
               ],

    demo_mgr:start_link(),

    cowboy:start_http(socketio_http_listener, 100, [{host, "127.0.0.1"},
                                                    {port, 8080}],
                      [{dispatch, Dispatch}]
                     ).

%% ---- Handlers
open(Pid, Sid) ->
    error_logger:info_msg("open ~p ~p~n", [Pid, Sid]),
    demo_mgr:add_session(Pid),
    #session_state{}.

recv(_Pid, _Sid, {json, <<>>, Json}, SessionState = #session_state{}) ->
    error_logger:info_msg("recv json ~p~n", [Json]),
    demo_mgr:publish_to_all(Json),
    SessionState;

recv(Pid, _Sid, {message, <<>>, Message}, SessionState = #session_state{}) ->
    socketio_session:send_message(Pid, Message),
    SessionState;

recv(Pid, Sid, Message, SessionState = #session_state{}) ->
    error_logger:info_msg("recv ~p ~p ~p~n", [Pid, Sid, Message]),
    SessionState.

close(Pid, Sid, _SessionState = #session_state{}) ->
    error_logger:info_msg("close ~p ~p~n", [Pid, Sid]),
    demo_mgr:remove_session(Pid),
    ok.
