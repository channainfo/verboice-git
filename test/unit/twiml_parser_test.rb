require 'test_helper'

class TwimlParserTest < ActiveSupport::TestCase
  context "can parse?" do
    should "parse" do
      xml = Nokogiri.XML '<Response><Say>Hello</Say></Response>'
      assert TwimlParser.can_parse?(xml)
    end

    should "not parse" do
      xml = Nokogiri.XML '<phoneml></phoneml>'
      assert !TwimlParser.can_parse?(xml)
    end
  end

  test "parse play" do
    assert_parse '<Response><Play>http://foo</Play></Response>', [:play_url => 'http://foo']
  end

  context "gather" do
    def gather_commands(capture_options = {}, next_commands = [], callback_options = {})
      callback_options[:params] = {:Digits => :digits}
      [
        {:capture => capture_options},
        {:if => {:condition => 'timeout || finish_key', :then => next_commands, :else => {:callback => callback_options}}}
      ]
    end

    should "parse gather" do
      assert_parse '<Response><Gather/></Response>', gather_commands({:min => 1, :max => Float::INFINITY})
    end

    should "parse gather with attributes" do
      assert_parse '<Response><Gather timeout="3" finishOnKey="*" numDigits="4"/></Response>',
        gather_commands(:timeout => 3, :finish_on_key => "*", :min => 4, :max => 4)
    end

    should "parse gather with emedded play" do
      assert_parse '<Response><Gather><Play>http://foo</Play></Gather></Response>',
        gather_commands(:play => 'http://foo', :min => 1, :max => Float::INFINITY)
    end

    should "parse gather with emedded play" do
      assert_parse '<Response><Gather><Say>hello</Say></Gather></Response>',
        gather_commands(:say => 'hello', :min => 1, :max => Float::INFINITY)
    end

    should "parse gather with next commands on timeout/finish_key" do
      assert_parse '<Response><Gather/><Hangup /></Response>', gather_commands({:min => 1, :max => Float::INFINITY}, [:hangup])
    end

    should "parse gather with callback options" do
      assert_parse '<Response><Gather action="http://www.domain.com/controller/action" method="GET"/></Response>',
        gather_commands({:min => 1, :max => Float::INFINITY}, [], {:url => 'http://www.domain.com/controller/action', :method => 'GET'})
    end
  end

  context "redirect" do
    should "parse redirect" do
      assert_parse '<Response><Redirect>http://foo</Redirect></Response>', [:callback => {:url => 'http://foo', :method => 'post'}]
    end

    should "parse redirect with method" do
      assert_parse '<Response><Redirect method="get">http://foo</Redirect></Response>', [:callback => {:url => 'http://foo', :method => 'get'}]
    end
  end

  test "parse say" do
    assert_parse '<Response><Say>Hello</Say></Response>', [:say => 'Hello']
  end

  test "parse hangup" do
    assert_parse '<Response><Hangup/></Response>', [:hangup]
  end

  test "parse pause" do
    assert_parse '<Response><Pause /></Response>', [:pause => 1]
  end

  test "parse pause with length" do
    assert_parse '<Response><Pause length="3"/></Response>', [:pause => 3]
  end

  test "parse bridge" do
    assert_parse '<Response><Bridge session_id="123"/></Response>', [:bridge => '123']
  end

  context "dial" do
    should "parse basic command" do
      assert_parse '<Response><Dial>1234</Dial></Response>', [:dial => {:number => '1234'}]
    end

    should "parse with channel" do
      assert_parse "<Response><Dial channel='foo'>1234</Dial></Response>", [:dial => {:number => '1234', :channel => 'foo'}]
    end

    should "parse with caller id" do
      assert_parse "<Response><Dial callerId='foo'>1234</Dial></Response>", [:dial => {:number => '1234', :caller_id => 'foo'}]
    end

    should "parse with action" do
      assert_parse "<Response><Dial action='http://foo'>1234</Dial></Response>",
        [
          {:dial => {:number => '1234'}},
          {:callback => {:url => 'http://foo', :params => {:DialCallStatus => :dial_status}}}
        ]
    end

    should "parse with action and method" do
      assert_parse "<Response><Dial action='http://foo' method='get'>1234</Dial></Response>",
        [
          {:dial => {:number => '1234'}},
          {:callback => {:url => 'http://foo', :method => 'get', :params => {:DialCallStatus => :dial_status}}}
        ]
    end

    should "ignore following commands if action is given" do
      assert_parse "<Response><Dial action='http://foo'>1234</Dial><Hangup/></Response>",
        [
          {:dial => {:number => '1234'}},
          {:callback => {:url => 'http://foo', :params => {:DialCallStatus => :dial_status}}}
        ]
    end

    should "include following commands if action is not given" do
      assert_parse "<Response><Dial>1234</Dial><Hangup/></Response>", [{:dial => {:number => '1234'}}, :hangup]
    end
  end

  def assert_parse(xml, result)
    assert_equal result, XmlParser.parse(xml)
  end
end
