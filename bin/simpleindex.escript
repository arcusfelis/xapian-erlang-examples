#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").


main([Path]) ->
    load_deps(),
    {ok, Server} = xapian_server:open(Path, [write, create, open]),
    read_cycle(Server, []).


read_cycle(Server, Acc) ->
    case io:get_line("") of
        eof -> 
            handle_paragraph(Server, Acc),
            xapian_server:close(Server);

        "" ->
            handle_paragraph(Server, Acc),
            read_cycle(Server, []);

        Line ->
            read_cycle(Server, [Line|Acc])
    end.



%% Lines are reversed.
handle_paragraph(Server, [Line|Lines]) ->
    index_document(Server, lines_to_data(Lines, [Line]));

handle_paragraph(_Server, []) ->
    ok.
    

lines_to_data([Line|Lines], Data) ->
    lines_to_data(Lines, [Line, $ |Data]);

lines_to_data([], Data) ->
    Data.


index_document(Server, Data) ->
    Document = 
    [ #x_stemmer{language = "english"}
    , #x_text{value = Data}
    , #x_data{value = Data}
    ],
    xapian_server:add_document(Server, Document).
        

load_deps() ->
    ScriptDir = filename:dirname(escript:script_name()),
    [ code:add_pathz(Dir) 
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ],
    xapian:start().
