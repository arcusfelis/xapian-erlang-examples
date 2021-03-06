#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").
-include_lib("stdlib/include/qlc.hrl").

%% `title' is a slot field.
-record(document, {docid, rank, title, max_dimension, year_made}).

main(Args = [_, _]) ->
    main(Args ++ [0]);

main(Args = [_, _, _]) ->
    main(Args ++ [10]);

main([Path, QueryStr, Offset, PageSize]) ->
    load_deps(),
    search(Path, QueryStr, Offset, PageSize).


search(Path, QueryStr, Offset, PageSize) ->
    Params =
    [ #x_stemmer{language = "english"}
    , #x_prefix_name{name = title,          prefix = "S"}
    , #x_prefix_name{name = description,    prefix = "XD"}
    , #x_value_name{name = max_dimension,   slot = 0, type = float}
    , #x_value_name{name = year_made,       slot = 1, type = float}
    , #x_value_name{name = title,           slot = 2}              
    ],
    {ok, Server} = xapian_server:open(Path, Params),
    Procs = [xapian_resource:number_value_range_processor(0, "mm", suffix)
            ,xapian_resource:number_value_range_processor(1) ],
    Query = #x_query_string{
        value = QueryStr,
        parser = #x_query_parser{stemming_strategy = some,
                                 value_range_processors = Procs}},
    EnquireRes = xapian_server:enquire(Server, Query),
    MSetParams = #x_match_set{
        enquire = EnquireRes,
        offset = Offset,
        max_items = PageSize},
    MSetRes    = xapian_server:match_set(Server, MSetParams),
    print_query_result(Server, MSetRes),
    ok.

print_query_result(Server, MSetRes) ->
    Meta = xapian_record:record(document, record_info(fields, document)),
    Table = xapian_mset_qlc:table(Server, MSetRes, Meta),
    qlc:fold(fun(Rec, ok) -> print_document(Rec) end, ok, Table),
    xapian_server:release_table(Server, Table),
    ok.

print_document(#document{ docid = DocId, rank = Rank, title = Title, 
                         max_dimension = Size, year_made = Year}) ->
    io:format("~2B: #~3..0B ~6s ~6s   |~-40ts|~n",
              [Rank + 1, DocId, to_string(Size), to_string(round(Year)), Title]).

to_string(X) ->
    io_lib:format("~p", [X]).
    
load_deps() ->
    ScriptDir = filename:dirname(escript:script_name()),
    [ code:add_pathz(Dir)
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ],
    xapian:start().
