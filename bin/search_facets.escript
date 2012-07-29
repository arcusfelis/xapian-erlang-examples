#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").
-include_lib("stdlib/include/qlc.hrl").

%% `title' is a slot field.
-record(document, {docid, rank, title}).
-record(spy_term, {value, freq}).

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
    , #x_value_name{name = collection,      slot = 0}
    , #x_value_name{name = maker,           slot = 1}
    , #x_value_name{name = title,           slot = 2}
    ],
    {ok, Server} = xapian_server:open(Path, Params),
    Query = #x_query_string{
        value = QueryStr,
        parser = #x_query_parser{stemming_strategy = some}},
    MakerSpyRes = xapian_match_spy:value_count(Server, maker),
    EnquireRes = xapian_server:enquire(Server, Query),
    MSetParams = #x_match_set{
        enquire = EnquireRes,
        spies = [MakerSpyRes],
        offset = Offset,
        max_items = PageSize},
    MSetRes    = xapian_server:match_set(Server, MSetParams),
    print_query_result(Server, MSetRes),
    print_facets(Server, MakerSpyRes),
    ok.

print_query_result(Server, MSetRes) ->
    Meta = xapian_record:record(document, record_info(fields, document)),
    Table = xapian_mset_qlc:table(Server, MSetRes, Meta),
    qlc:fold(fun(Rec, ok) -> print_document(Rec) end, ok, Table),
    xapian_server:release_table(Server, Table),
    ok.

print_document(#document{ docid = DocId, rank = Rank, title = Title}) ->
    io:format("~B: docid=~B ~ts\n", [Rank + 1, DocId, Title]).


%% Shows facets, sorted by a value.
print_facets(Server, SpyRes) ->
    Meta = xapian_term_record:record(spy_term,
                record_info(fields, spy_term)),
    Table = xapian_term_qlc:value_count_match_spy_table(
        Server, SpyRes, Meta),
    qlc:fold(fun(Rec, ok) -> print_facet(Rec) end, ok, Table),
    xapian_server:release_table(Server, Table),
    ok.

print_facet(#spy_term{value = Value, freq = Freq}) ->
    io:format("Facet: ~ts; count: ~B\n", [Value, Freq]).

    
load_deps() ->
    ScriptDir = filename:dirname(escript:script_name()),
    [ code:add_pathz(Dir)
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ],
    xapian:start().
