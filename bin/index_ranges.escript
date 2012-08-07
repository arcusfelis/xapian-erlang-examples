#!/usr/bin/env escript

-include("../deps/xapian/include/xapian.hrl").
-include_lib("stdlib/include/qlc.hrl").


-record(object, {
    id,
    description,
    title,
    mesurements,
    date_made
}).

object_header() ->
    #object{
        id = <<"id_NUMBER">>,
        description = <<"DESCRIPTION">>,
        title = <<"TITLE">>,
        mesurements = <<"MEASUREMENTS">>,
        date_made = <<"DATE_MADE">>
    }.

main([DataPath, DbPath]) ->
    load_deps(),
    DbParams = [write, create, open
        , #x_value_name{name = max_dimension,   slot = 0, type = float}
        , #x_value_name{name = year_made,       slot = 1, type = float}
        , #x_value_name{name = title,           slot = 2}
        ],

    {ok, Server} = xapian_server:open(DbPath, DbParams),
    {ok, Fd} = file:open(DataPath, [binary]),
    Parser = csv_parser:file_parser(Fd),
    %% The first line is a header.
    {Header, Parser2} = csv_parser:read_record(Parser),
    Converter = csv_record:create_converter(object_header(), Header),
    QlcTable = csv_qlc:table(Parser2, Converter),
    QlcQuery = qlc:q([index_document(Server, X) || X <- QlcTable]),
    qlc:e(QlcQuery),
    file:close(Fd),
    ok.


index_document(Server, Data) ->
    #object{
        id = Identifier,
        description = Description,
        title = Title,
        mesurements = Measurements,
        date_made = DateMade
    } = Data,
    %% Generate an id for the document.
    IdTerm = <<"Q", Identifier/binary>>,
    Document = 
    [ #x_stemmer{language = "english"}
    %% Index each field with a suitable prefix.
    , #x_text{prefix = "S",  value = Title}
    , #x_text{prefix = "XD", value = Description}

    %% Index fields without prefixes for general search.
    , #x_text{value = Title}
    , #x_delta{}
    , #x_text{value = Description}

    %% title is for the display purpose.
    , #x_value{slot = title,        value = Title}

    %% Add an identifier.
    , #x_term{frequency = 0, value = IdTerm}
    ] ++ handle_measurements(Measurements) ++ handle_date_made(DateMade),
    %% We use the identifier to ensure each object ends up in the
    %% database only once no matter how many times we run the
    %% indexer.
    xapian_server:replace_or_create_document(Server, IdTerm, Document).

handle_measurements(S) ->
    case numbers_from_string(S) of
        [] -> [];
        Ns -> [#x_value{slot = max_dimension, value = lists:max(Ns)}]
    end.

handle_date_made(S) ->
    case numbers_from_string(S) of
        [] -> [];
        [Made|_] -> [#x_value{slot = year_made, value = Made}]
    end.

numbers_from_string(S) ->
    ReExtractNumbers = "[0-9]+(\\\.[0-9]+|)",
    case re:run(S, ReExtractNumbers, [global, {capture, first, list}]) of
        nomatch -> [];
        {match, Numbers} -> 
            [list_to_number(N) || [N] <- Numbers]
    end.

list_to_number(L) ->
    case lists:member($., L) of 
        true  -> list_to_float(L); 
        false -> list_to_integer(L)
    end.


load_deps() ->
    ScriptDir = filename:dirname(escript:script_name()),
    [ code:add_pathz(Dir) 
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ],
    xapian:start().
