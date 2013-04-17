-module(channel).
-export([find_all_sip/0, domain/1, number/1, limit/1, broker/1, username/1, password/1, is_outbound/1, register/1]).
-define(TABLE_NAME, "channels").

-define(MAP(Channel),
  {ok, [Config]} = yaml:load(Channel#channel.config),
  Channel#channel{config = Config}
  ).

-include("model.hrl").

find_all_sip() ->
  find_all({type, in, ["Channels::Sip", "Channels::CustomSip", "Channels::TemplateBasedSip"]}).

domain(Channel = #channel{type = <<"Channels::TemplateBasedSip">>}) ->
  case proplists:get_value(<<"kind">>, Channel#channel.config) of
    % TODO: Load template domains from yaml file
    <<"Callcentric">> -> "callcentric.com";
    <<"Skype">> -> "sip.skype.com"
  end;

domain(#channel{config = Config}) ->
  proplists:get_value(<<"domain">>, Config).

number(#channel{config = Config}) ->
  binary_to_list(proplists:get_value(<<"number">>, Config)).

username(#channel{config = Config}) ->
  binary_to_list(proplists:get_value(<<"username">>, Config)).

password(#channel{config = Config}) ->
  binary_to_list(proplists:get_value(<<"password">>, Config)).

is_outbound(#channel{type = <<"Channels::TemplateBasedSip">>}) ->
  true;

is_outbound(#channel{config = Config}) ->
  case proplists:get_value(<<"password">>, Config) of
    <<"outbound">> -> true;
    <<"both">> -> true;
    _ -> false
  end.

register(#channel{type = <<"Channels::TemplateBasedSip">>}) ->
  true;

register(#channel{config = Config}) ->
  case proplists:get_value(<<"register">>, Config) of
    <<"true">> -> true;
    <<"1">> -> true;
    _ -> false
  end.

limit(_) ->
  1.

broker(_) ->
  asterisk_broker.