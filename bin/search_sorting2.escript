#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").
-include_lib("stdlib/include/qlc.hrl").

%% `title' is a slot field.
-record(document, {docid, rank, name, admitted, population}).


main(Args = [_, _]) ->
    main(Args ++ [0]);

main(Args = [_, _, _]) ->
    main(Args ++ [10]);

main([Path, QueryStr, Offset, PageSize]) ->
    load_deps(),
    search(Path, QueryStr, Offset, PageSize).


open_params() ->
    [ #x_stemmer{language = "english"}
    , #x_value_name{slot = 1, name = admitted_year, type = float}
    , #x_value_name{slot = 2, name = admitted}
    , #x_value_name{slot = 3, name = population, type = float}
    , #x_value_name{slot = 4, name = name}
    , #x_prefix_name{name = title, prefix = "S"}
    , #x_prefix_name{name = description, prefix = "XD"}
    ].


search(Path, QueryStr, Offset, PageSize) ->
    {ok, Server} = xapian_server:open(Path, open_params()),
    EnquireDescriptor = enquire_descriptor(main_query(QueryStr), 
                                           order(Server)),
    EnquireRes = xapian_server:enquire(Server, EnquireDescriptor),
    MSetParams = #x_match_set{
        enquire = EnquireRes,
        offset = Offset,
        max_items = PageSize},
    MSetRes    = xapian_server:match_set(Server, MSetParams),
    print_query_result(Server, MSetRes),
    ok.


enquire_descriptor(Query, Key) ->
     #x_enquire{value = Query,
                order = #x_sort_order{type = key_relevance,
                                      value = Key}}.

order(Server) ->
    Slots = [admitted_year, {reverse, population}],
    xapian_resource:multi_value_key_maker(Server, Slots).


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


print_document(#document{ docid = DocId, rank = Rank, 
                          name = Name, admitted = Date, population = Pop}) ->
    io:format("~2B: #~3..0B   ~-25ts   ~8ts   ~10B~n", 
              [Rank + 1, DocId, Name, Date, round(Pop)]).

    
load_deps() ->
    ScriptDir = filename:dirname(escript:script_name()),
    [ code:add_pathz(Dir)
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ],
    xapian:start().
