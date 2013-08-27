-module(channel_queue).
-export([start_link/1, enqueue/1, wakeup/1]).

-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(QUEUE(ChannelId), {global, {channel, ChannelId}}).
-include("db.hrl").

-record(state, {self, active = true, channel, current_calls = 0, sessions, max_calls, queued_calls}).

start_link(Channel = #channel{id = Id}) ->
  gen_server:start_link(?QUEUE(Id), ?MODULE, Channel, []).

%% Enqueue a new ready call. The queue will immediatelly dispatch to broker unless it's busy
enqueue(QueuedCall = #queued_call{channel_id = ChannelId}) ->
  gen_server:cast(?QUEUE(ChannelId), {enqueue, QueuedCall}).

%% Notify the queue that it can now dispatch ready calls to the broker
wakeup(ChannelId) ->
  gen_server:cast(?QUEUE(ChannelId), wakeup).

%% @private
init(Channel) ->
  {ok, #state{
    self = ?QUEUE(Channel#channel.id),
    channel = Channel,
    max_calls = Channel:limit(),
    queued_calls = queue:new(),
    sessions = ordsets:new()
  }}.

%% @private
handle_call(_Request, _From, State) ->
  {reply, {error, unknown_call}, State}.

%% @private
handle_cast({enqueue, QueuedCall}, State = #state{queued_calls = Queue}) ->
  Queue2 = queue:in(QueuedCall, Queue),
  {noreply, do_dispatch(State#state{queued_calls = Queue2})};

handle_cast(wakeup, State) ->
  {noreply, do_dispatch(State#state{active = true})};

handle_cast(_Msg, State) ->
  {noreply, State}.

%% @private
handle_info({'DOWN', _, process, Pid, _}, State = #state{current_calls = C, sessions = Sessions}) ->
  case ordsets:is_element(Pid, Sessions) of
    true ->
      NewSessions = ordsets:del_element(Pid, Sessions),
      timer:apply_after(timer:seconds(2), gen_server, cast, [self(), wakeup]),
      {noreply, State#state{sessions = NewSessions, current_calls = C - 1}};
    false ->
      {noreply, State}
  end;

handle_info(_Info, State) ->
  {noreply, State}.

%% @private
terminate(_Reason, _State) ->
  ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

do_dispatch(State = #state{active = false}) -> State;
do_dispatch(State = #state{current_calls = C, max_calls = M}) when C >= M -> State;
do_dispatch(State = #state{current_calls = C, queued_calls = Q, sessions = S}) ->
  case queue:out(Q) of
    {empty, _} -> State;
    {{value, Call}, Q2} ->
      case broker:dispatch(State#state.channel, Call) of
        {ok, SessionPid} ->
          Call:delete(),
          monitor(process, SessionPid),
          NewSessions = ordsets:add_element(SessionPid, S),
          do_dispatch(State#state{current_calls = C + 1, queued_calls = Q2, sessions = NewSessions});
        error ->
          Call:delete(),
          do_dispatch(State#state{queued_calls = Q2});
        unavailable ->
          State#state{active = false}
      end
  end.
