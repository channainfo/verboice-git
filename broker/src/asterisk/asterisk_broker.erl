-module(asterisk_broker).
-export([start_link/0, init/0, notify_ready/0, dispatch/1, create_channel/1, destroy_channel/1, dial_address/2]).

-behaviour(broker).

-include("session.hrl").
-include("db.hrl").

start_link() ->
  broker:start_link(?MODULE).

init() ->
  ami_events:add_handler(asterisk_event_handler, []),
  ami_client:connect().

notify_ready() ->
  broker:notify_ready(?MODULE).

create_channel(_Id) ->
  asterisk_channel_srv:regenerate_config().

destroy_channel(_Id) ->
  asterisk_channel_srv:regenerate_config().

dial_address(#channel{type = <<"Channels::Custom">>, config = Config}, Address) ->
  DialString = proplists:get_value("dial_string", Config),
  util:interpolate(list_to_binary(DialString), fun(Key) ->
    case Key of
      <<"number">> -> Address;
      _ -> <<>>
    end
  end);

dial_address(#channel{id = Id}, Address) ->
  ["SIP/verboice_", integer_to_list(Id), "-outbound/", util:to_string(Address)].

dispatch(#session{session_id = SessionId, channel = Channel, address = Address}) ->
  CallerId = channel:number(Channel),
  DialAddress = dial_address(Channel, Address),
  {ok, BrokerPort} = application:get_env(broker_port),
  ami_client:originate([
    {callerid, CallerId},
    {channel, DialAddress},
    {application, "AGI"},
    {data, ["agi://localhost:", integer_to_list(BrokerPort), ",", SessionId]},
    {async, true},
    {actionid, SessionId},
    {variable, ["verboice_session_id=", SessionId]}
  ]).
