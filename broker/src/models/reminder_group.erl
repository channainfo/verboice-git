-module(reminder_group).
-export([has_address/2, register_address/2, deregister_address/2]).
-define(TABLE_NAME, "ext_reminder_groups").

-include_lib("erl_dbmodel/include/model.hrl").

has_address(AddressBin, #reminder_group{addresses = AddrYaml}) ->
  Addresses = get_addresses(AddrYaml),
  Address = binary_to_list(AddressBin),
  lists:member(Address, Addresses).

register_address(AddressBin, ReminderGroup = #reminder_group{addresses = AddrYaml}) ->
  case ReminderGroup:has_address(AddressBin) of
    true -> ReminderGroup;
    false ->
      Addresses = get_addresses(AddrYaml),
      Address = binary_to_list(AddressBin),
      NewAddresses = lists:append(Addresses, [Address]),
      ReminderGroup#reminder_group{addresses = serialize_yaml(NewAddresses)}
  end.

deregister_address(AddressBin, ReminderGroup = #reminder_group{addresses = AddrYaml}) ->
  case ReminderGroup:has_address(AddressBin) of
    true -> 
      Addresses = get_addresses(AddrYaml),
      Address = binary_to_list(AddressBin),
      ReminderGroup#reminder_group{addresses = serialize_yaml(lists:delete(Address, Addresses))};
    false ->
      ReminderGroup
  end.

serialize_yaml(Addresses) ->
  serialize_yaml(Addresses, <<"---\n">>).

serialize_yaml([], Yaml) -> Yaml;
serialize_yaml([Address | Rest], Yaml) ->
  AddressBin = list_to_binary(Address),
  serialize_yaml(Rest, <<Yaml/binary, "- '", AddressBin/binary, "'\n">>).

get_addresses(AddrYaml) ->
  case AddrYaml of
    undefined -> [];
    Yaml ->
      {ok, [Doc]} = yaml:load(Yaml, [{schema, yaml_schema_ruby}]),
      Doc
  end.