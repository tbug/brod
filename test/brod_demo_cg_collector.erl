%%%
%%%   Copyright (c) 2016 Klarna AB
%%%
%%%   Licensed under the Apache License, Version 2.0 (the "License");
%%%   you may not use this file except in compliance with the License.
%%%   You may obtain a copy of the License at
%%%
%%%       http://www.apache.org/licenses/LICENSE-2.0
%%%
%%%   Unless required by applicable law or agreed to in writing, software
%%%   distributed under the License is distributed on an "AS IS" BASIS,
%%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%%   See the License for the specific language governing permissions and
%%%   limitations under the License.
%%%

%%%=============================================================================
%%% @doc
%%% This is a topic subscriber example
%%% The subscriber subscribes to all partition of the consumer offset topic
%%% (by default __consumer_offsets), decode the messages and put the values
%%% to an ETS table.
%%% see kpro_consumer_group.erl for details about data schema
%%% @copyright 2016 Klarna AB
%%% @end
%%%=============================================================================

-module(brod_demo_cg_collector).

-behaviour(brod_topic_subscriber).

-include_lib("brod/include/brod.hrl").

-define(CLIENT, ?MODULE).
-define(ETS, consumer_offsets).

-export([ start/0
        , start/1
        , start/2
        , start/3
        , start/4
        ]).

%% brod_topic_subscriber callback
-export([ init/2
        , handle_message/3
        ]).

start() ->
  start([{"localhost", 9092}]).
start(BootstrapHosts) ->
  start(BootstrapHosts, ?CLIENT).
start(BootstrapHosts, ClientId) ->
  start(BootstrapHosts, ClientId, <<"__consumer_offsets">>).
start(BootstrapHosts, ClientId, CgTopic) ->
  start(BootstrapHosts, ClientId, CgTopic, ?ETS).

start(BootstrapHosts, ClientId, CgTopic, EtsName) ->
  ClientConfig = [],
  {ok, _} = application:ensure_all_started(brod),
  ok = brod:start_client(BootstrapHosts, ClientId, ClientConfig),
  brod_topic_subscriber:start_link(ClientId, CgTopic, _Partitions = all,
                                   [{begin_offset, earliest}],
                                   ?MODULE, EtsName).

init(_Topic, EtsName) ->
  EtsName = ets:new(EtsName, [named_table, ordered_set, public]),
  {ok, [], #{ets => EtsName}}.

handle_message(_Partition, #kafka_message{key = KeyBin, value = ValueBin},
               #{ets := Ets} = State) ->
  {Tag, Key, Value} = kpro_consumer_group:decode(KeyBin, ValueBin),
  Kf = fun(K) -> {K, V} = lists:keyfind(K, 1, Key), V end,
  case Tag of
    offset -> update_ets(Ets, {Kf(group_id), Kf(topic), Kf(partition)}, Value);
    group  -> update_ets(Ets, Kf(group_id), Value)
  end,
  {ok, ack, State}.

%%%_* Internal Functions =======================================================

update_ets(Ets, Key, _Value = []) -> ets:delete(Ets, Key);
update_ets(Ets, Key, Value)       -> ets:insert(Ets, {Key, Value}).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
