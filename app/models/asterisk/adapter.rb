module Asterisk
  class Adapter
    SoundsDir = Rails.configuration.asterisk_configuration[:sounds_dir]
    SoundsPath = "#{SoundsDir}/verboice/"
    FileUtils.mkdir_p SoundsPath

    include BaseAdapter

    def initialize(context)
      @context = context
    end

    def channel_id; @context['arg_1']; end
    def call_log_id; @context['arg_2']; end
    def caller_id; @context['callerid']; end

    def answer
      @context.answer
    end

    def hangup
      @context.hangup
      @context.close_connection
    end

    def sound_path_for(basename)
      "#{SoundsPath}#{basename}.gsm"
    end

    def play(filename, escape_digits = nil)
      filename = filename[SoundsPath.length .. -5] # Remove SoundsPath and .gsm extension
      line = @context.stream_file("verboice/#{filename}", escape_digits)
      if line.result == '-1'
        raise Exception.new 'Error while playing file'
      end
      ascii_to_number line.result
    end

    def capture(options)
      digits = ''
      digits = play(options[:play], '0123456789#*') || '' if options[:play]
      return nil if digits != '' && options[:finish_on_key].include?(digits)

      until digits.length == options[:max]
        digit = capture_digit(options[:timeout].to_i * 1000)
        break if digit.nil? || options[:finish_on_key].include?(digit)

        digits << digit
      end
      digits.length < options[:min] ? nil : digits
    end

    def record
      @context.record_file "#{SoundsPath}/foo", 'wav', '0123456789*#', '5000', 'beep'
    end

    def is_answering_machine?
      # TODO: add configuration for this. For now it's kind of annoying when it doesn't work.
      return false

      amd_result = @context.exec('amd').result
      return false if amd_result.to_i == -2

      @context.get_variable('amdstatus').raw =~ /MACHINE/
    end

    private

    def capture_digit(timeout)
      line = @context.wait_for_digit timeout
      ascii_to_number line.result
    end

    def ascii_to_number(ascii)
      case ascii
      when '0' then nil
      when '35' then "#"
      when '42' then "*"
      else "#{ascii.to_i - 48}"
      end
    end
  end
end
