#!/usr/bin/env escript

-include_lib("stdlib/include/qlc.hrl").
-include("../deps/xapian/include/xapian.hrl").

-record(state, {name, description, motto, admitted, population, order}).
-record(date, {month, day, year}).

open_params() ->
    [open, create, write
    , #x_value_name{slot = 1, name = admitted_year, type = float}
    , #x_value_name{slot = 2, name = admitted}
    , #x_value_name{slot = 3, name = population, type = float}
    , #x_value_name{slot = 4, name = name}
    ].

main([DataPath, DbPath]) ->
    load_deps(),
    {ok, Fd} = file:open(DataPath, [binary]),
    {ok, Server} = xapian_server:open(DbPath, open_params()),
    Parser = csv_parser:file_parser(Fd),
    {Header, Parser2} = csv_parser:read_record(Parser),
    NameRec = #state{name        = <<"name">>,
                     description = <<"description">>,
                     motto       = <<"motto">>,
                     admitted    = <<"admitted">>,
                     population  = <<"population">>},
    Converter = csv_record:create_converter(NameRec, Header),
    TableParams = [{position_field, #state.order}],
    QlcTable = csv_qlc:table(Parser2, Converter, TableParams),
    QlcQuery = qlc:q([index_document(Server, Doc) || Doc <- QlcTable]),
    qlc:e(QlcQuery),
    file:close(Fd),
    ok.


index_document(Server, Data) ->
    #state{
        name = Name,
        description = Description,
        motto = Motto,
        admitted = Admitted,
        population = Population,
        order = Order
    } = Data,
    %% Generate an id for the document.
    %% "Q" is a prefix.
    IdTerm = list_to_binary([$Q | integer_to_list(Order)]),
    Document =
    [ #x_stemmer{language = "english"}
    %% Index each field with a suitable prefix.
    , #x_text{prefix = "S",  value = Name}
    , #x_text{prefix = "XD", value = Description}
    , #x_text{prefix = "XM", value = Motto}

    %% Index fields without prefixes for general search.
    , #x_text{value = Name}
    , #x_delta{}
    , #x_text{value = Description}
    , #x_delta{}
    , #x_text{value = Motto}

    , #x_value{slot = name, value = Name}

    %% Add an identifier.
    , #x_term{frequency = 0, value = IdTerm}
    ] ++ index_admitted(Admitted) ++ index_population(Population),
    %% We use the identifier to ensure each object ends up in the
    %% database only once no matter how many times we run the
    %% indexer.
    xapian_server:replace_or_create_document(Server, IdTerm, Document).


index_admitted(<<"">>) -> [];
index_admitted(Admitted) ->
    %% Get a record of parsed binaries.
    case parse_date(Admitted) of
    undefined -> [];
    Parsed = #date{year = Year} -> 
        YearNum = list_to_integer(binary_to_list(Year)),
        [#x_value{slot = admitted, value = date_to_string(Parsed)} % YYYYMMDD
         ,#x_value{slot = admitted_year, value = YearNum}
        ]
    end.


index_population(<<"">>) -> [];
index_population(Population) ->
    case handle_population(Population) of
        undefined -> [];
        PopulationNumber ->
            [#x_value{slot = population, value = PopulationNumber}]
    end.


load_deps() ->                                                        
    ScriptDir = filename:dirname(escript:script_name()),              
    [ code:add_pathz(Dir)                                             
        || Dir <- filelib:wildcard(ScriptDir ++ "/../deps/*/ebin") ], 
    xapian:start().                                                   


%% Split "(2010) 123,456,789" on tokens: "(2010)" and "123,456,789"
handle_population(Population) ->
    Population1 = binary:replace(Population,  <<"(">>, <<" (">>, [global]),
    Population2 = binary:replace(Population1, <<")">>, <<") ">>, [global]),
    case binary:split(Population2, <<" ">>, [global]) of
    Tokens -> 
        select_pop_token(Tokens);
    _ -> 
       undefined 
    end.


%% TODO: TESTME
%% Extract "123,456,789" from the token list.
select_pop_token([<<X, _/binary>> = WithCommas|_]) when X >= $0, X =< $9 ->
    BinNum = binary:replace(WithCommas, <<$,>>, <<>>, [global]),
    list_to_integer(binary_to_list(BinNum));
%% Bad token
select_pop_token([_|T]) ->
    select_pop_token(T);
select_pop_token([]) ->
    undefined.


parse_date(Str) ->
    RE = "^(\\w*) (\\d{1,2}), (\\d{4})",
    Matches = re:run(Str, RE, [{capture, all, binary}]),
    case Matches of
        {match, [_WholePattMatch, Month, Day, Year]} ->
            #date{month = Month, day = Day, year = Year};
        _ -> %% TODO: any errors are ignored
            undefined
    end.


%% YYYYMMDD
%% #date{} contains raw binaries.
date_to_string(#date{month = Month, day = Day, year = YYYY}) ->
    MM = month_name_to_mm(Month),
    DD = encode_2digit_day(Day),
    <<YYYY/binary, MM/binary, DD/binary>>.
    

encode_2digit_day(<<X>>) ->
    <<$0, X>>;
encode_2digit_day(B) ->
    B.


month_name_to_mm(Name) ->
    Str  = binary_to_list(Name),
    LStr = string:to_lower(Str),
    Atom = list_to_atom(LStr),
    Num  = month_name_to_number(Atom),
    IOL  = io_lib:format("~2..0B", [Num]),
    iolist_to_binary(IOL).


month_name_to_number(january)   -> 1;
month_name_to_number(february)  -> 2;

month_name_to_number(march)     -> 3;
month_name_to_number(april)     -> 4;
month_name_to_number(may)       -> 5;

month_name_to_number(june)      -> 6;
month_name_to_number(july)      -> 7;
month_name_to_number(august)    -> 8;

month_name_to_number(september) -> 9;
month_name_to_number(october)   -> 10;
month_name_to_number(november)  -> 11;
month_name_to_number(december)  -> 12.

            
