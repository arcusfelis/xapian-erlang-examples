#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").
-include_lib("stdlib/include/qlc.hrl").

%% `title' is a slot field.
-record(document, {docid, rank, title}).

main([Path, QueryStr]) ->
    load_deps(),
    search(Path, QueryStr, 0, 10).


search(Path, QueryStr, Offset, PageSize) ->
    Params =
    [ #x_stemmer{language = "english"}
    , #x_prefix_name{name = material, prefix = "XM", is_boolean = true}
    , #x_value_name{name = title,     slot = 0}
    ],
    {ok, Server} = xapian_server:open(Path, Params),
    EnquireRes = xapian_server:enquire(Server, main_query(QueryStr)),
    MSetParams = #x_match_set{
        enquire = EnquireRes,
        offset = Offset,
        max_items = PageSize},
    MSetRes    = xapian_server:match_set(Server, MSetParams),
    print_query_result(Server, MSetRes),
    ok.


main_query(QueryStr) ->
    #x_query_string{
        value = QueryStr,
        parser = #x_query_parser{stemming_strategy = some}}.


print_query_result(Server, MSetRes) ->
    Meta = xapian_record:record(document, record_info(fields, document)),
    Table = xapian_mset_qlc:table(Server, MSetRes, Meta),
    qlc:fold(fun(Rec, ok) -> print_document(Rec) end, ok, Table),
    xapian_server:release_table(Server, Table),
    ok.

print_document(#document{ docid = DocId, rank = Rank, title = Title}) ->
    io:format("~B: #~3..0B ~ts\n", [Rank + 1, DocId, Title]).

    
load_deps() ->
    ScriptDir = filename:dirname(escript:script_name()),
    [ code:add_pathz(Dir)
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ],
    xapian:start().
