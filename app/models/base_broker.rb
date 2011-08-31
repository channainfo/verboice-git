class BaseBroker
  class << self
    attr_accessor :instance
  end

  def notify_call_queued channel
    return if reached_active_calls_limit?(channel)

    queued_call = channel.poll_call
    return unless queued_call

    session = queued_call.start
    store_session session

    call session
  end

  def reached_active_calls_limit?(channel)
    channel.has_limit? && active_calls_count_for(channel) >= channel.limit
  end

  def active_calls
    @active_calls ||= Hash.new {|hash, key| hash[key] = {}}
  end

  def active_calls_count_for(channel)
    active_calls[channel.id].length
  end

  def sessions
    @sessions ||= {}
  end

  def accept_call(pbx)
    session = find_or_create_session pbx
    session.call_log.address = pbx.caller_id unless session.call_log.address.present?
    begin
      session.run
    rescue Exception => ex
      finish_session_with_error session, ex.message
    else
      finish_session_successfully session
    end
  end

  def find_or_create_session(pbx)
    session = find_session pbx.session_id
    unless session
      session = Channel.find(pbx.channel_id).new_session
      store_session session
    end
    session.pbx = pbx
    session
  end

  def find_session(id)
    sessions[id]
  end

  def finish_session_successfully(session)
    session_id = session.id if session.is_a? Session

    session = sessions.delete session_id
    session.finish_successfully

    finish_session session
  end

  def finish_session_with_error(session, error_message)
    session = find_session session unless session.is_a? Session
    session.finish_with_error error_message

    finish_session session
  end

  private

  def store_session(session)
    sessions[session.id] = session
    active_calls[session.channel.id][session.id] = session
  end

  def finish_session(session)
    sessions.delete session.id
    active_calls[session.channel.id].delete session.id
  end
end