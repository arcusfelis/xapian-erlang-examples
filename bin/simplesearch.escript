#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").
-include_lib("stdlib/include/qlc.hrl").

-record(document, {docid, rank, percent, data}).

main([Path|Params]) ->
    load_deps(),
    {ok, Server} = xapian_drv:open(Path, []),
    Query = #x_query_string{
        string = string:join(Params, " "),
        parser = #x_query_parser{stemming_strategy = some}},
    EnquireRes = xapian_drv:enquire(Server, Query),
    MSetRes    = xapian_drv:match_set(Server, EnquireRes),
    [{matches_estimated, EstCount}] = 
    xapian_drv:mset_info(Server, MSetRes, [matches_estimated]),
    io:format("~B results found:\n", [EstCount]),
    Meta = xapian_record:record(document, record_info(fields, document)),
    QlcTable = xapian_mset_qlc:table(Server, MSetRes, Meta),
    QlcQuery = qlc:q([print_document(Doc) || Doc <- QlcTable]),
    qlc:e(QlcQuery).

    
print_document(#document{
    docid = DocId, rank = Rank, 
    percent = Percent, data = Data}) ->
    io:format("~B: ~B% docid=~B [~s]\n\n", [Rank + 1, Percent, DocId, Data]).
    

load_deps() ->
    ScriptDir = filename:dirname(escript:script_name()),
    [ code:add_pathz(Dir) 
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ],
    xapian:start().
