%% @doc Module that spawns threads to scan CVE-2015-1635, and each thread reports results to the main thread
-module(netscan).
-export([netscan_runscan/1]).

-include("defs.hrl").

%% @doc Run a scan across the provided network
-spec netscan_runscan(string()) -> [{inet:ip4_address(), scan_result()}].
netscan_runscan(Network) ->
    netscan_spawner(254, Network),
    netscan_receive(254, []).

%% @doc Collects replies from threads with results of scan.
-spec netscan_receive(0..254, [{inet:ip4_address(), scan_result()}]) ->
    [{inet:ip4_address(), scan_result()}].
netscan_receive(0, Results) ->
    Results;

netscan_receive(T, Results) ->
    receive
    {Address, Msg} ->
            %io:fwrite("~s With ~w received address ~w~n", [Msg,Address,R]),
            netscan_receive(T-1, Results ++ [{Address, Msg}])
    after ?TIMEOUT*2 ->
                Results
    end.

%% @doc Spawns a thread and receives a message with the address to scan
-spec netscan_spawner(byte(), _) -> 'ok'.
netscan_spawner(0, _) ->
    ok;

netscan_spawner(N, Network) ->
    Pid = spawn(fun() ->
            receive
            {From, execute} ->
                    {ok, Address} =
                    inet:parse_address(Network ++ integer_to_list(N)),
                    From ! {Address, mshttpsys:mshttpsys(Address) }
            end
    end),
    Pid ! {self(), execute},
    netscan_spawner(N-1, Network).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

netscan_runscan_test() ->
    ?assertEqual(netscan_spawner(1, "127.0.0."), ok),
    ?assertEqual(netscan_receive(1, []), [{{127, 0, 0, 1}, not_vulnerable}]).

-endif.
