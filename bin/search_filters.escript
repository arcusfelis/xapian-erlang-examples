#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").
-include_lib("stdlib/include/qlc.hrl").

%% `title' is a slot field.
-record(document, {docid, rank, title}).

main([Path, QueryStr | Materials]) ->
    load_deps(),
    search(Path, QueryStr, Materials, 0, 10).


search(Path, QueryStr, Materials, Offset, PageSize) ->
    Params =
    [ #x_stemmer{language = "english"}
    , #x_value_name{name = title, slot = 0}
    ],
    {ok, Server} = xapian_server:open(Path, Params),
    MainQuery = main_query(QueryStr),
    Query =
    case Materials of
        [] -> MainQuery;
        _  -> #x_query{op = 'FILTER', value = [MainQuery, 
                                               materials_query(Materials)]}
    end,
    EnquireRes = xapian_server:enquire(Server, Query),
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


materials_query(Materials) ->
    MatTerms = [material_to_term(X, "XM") || X <- Materials],
    #x_query{op = 'OR', value = MatTerms}.


material_to_term(Bin, Prefix) ->                      
    Str = unicode:characters_to_list(Bin),            
    LowerStr = ux_string:to_lower(Str),               
    unicode:characters_to_binary(Prefix ++ LowerStr). 


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
