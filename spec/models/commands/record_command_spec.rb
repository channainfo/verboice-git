require 'spec_helper'

module Commands
  describe RecordCommand do

    let(:pbx) { double('pbx') }

    before :each do
      pbx.stub :record
    end

    it "should create a recorded audio linking the saved audio file to the call log and contact" do
      contact = Contact.make
      project = Project.make account: contact.account
      call_flow = CallFlow.make project: project
      call_log = CallLog.make call_flow: call_flow

      session = Session.new :pbx => pbx, :call_log => call_log
      session.stub :address => contact.address

      cmd = RecordCommand.new 123, 'description'
      cmd.next = :next
      cmd.run(session).should == :next

      RecordedAudio.all.size.size

      RecordedAudio.all.size.should eq(1)
      RecordedAudio.first.call_log.should eq(call_log)
      RecordedAudio.first.contact.should eq(contact)
      RecordedAudio.first.key.should eq('123')
      RecordedAudio.first.description.should eq('description')
    end

    it "should create a Contact if it doesn't exist" do
      call_log = CallLog.make
      session = Session.new :pbx => pbx, :call_log => call_log
      session.stub :address => '1234xxx'

      Contact.all.size.should eq(0)

      cmd = RecordCommand.new 123, 'description'
      cmd.next = :next
      cmd.run(session).should == :next
      Contact.all.size.should eq(1)
      Contact.first.address.should eq('1234xxx')
      RecordedAudio.first.contact.should eq(Contact.first)
    end

    it "should create an anonymous contact using the call log id if the contact address is unknown" do
      call_log = CallLog.make id: 456
      session = Session.new :pbx => pbx, :call_log => call_log
      session.stub :address => nil

      Contact.all.size.should eq(0)

      cmd = RecordCommand.new 2, 'foo'
      cmd.next = :next
      cmd.run(session).should == :next
      Contact.all.size.should eq(1)
      Contact.first.address.should eq('Anonymous456')
      Contact.first.anonymous?.should eq(true)
      RecordedAudio.first.contact.should eq(Contact.first)
      details = call_log.structured_details

      details[0][:text].should == "Record user voice"
      details[1][:text].should == "Caller address is unknown. Recording 'foo' saved for contact Anonymous456."
    end

    it "should use an existing anonymous contact if the contact address is unknown but the contact is already created" do
      contact   = Contact.make address: 'Anonymous34', anonymous: true
      project   = Project.make account: contact.account
      call_flow = CallFlow.make project: project
      call_log  = CallLog.make call_flow: call_flow, id: 34
      session   = Session.new :pbx => pbx, :call_log => call_log
      session.stub :address => nil

      cmd = RecordCommand.new 2, 'foo'
      cmd.next = :next
      cmd.run(session).should == :next
      Contact.all.size.should eq(1)
      Contact.first.address.should eq('Anonymous34')
      RecordedAudio.first.contact.should eq(Contact.first)
      call_log.structured_details[1][:text].should == "Caller address is unknown. Recording 'foo' saved for contact Anonymous34."
    end


    describe 'pbx' do

      let(:call_log) { CallLog.make }
      let(:session) { Session.new(:pbx => pbx, :call_log => call_log, :address => '1234') }
      let(:filename) { RecordingManager.for(call_log).result_path_for('key') }

      it "should send pbx the record command with params" do
        pbx.should_receive(:record).with(filename, '25#', 5)

        cmd = RecordCommand.new 'key', 'desc', {:stop_keys => '25#', :timeout => 5}
        cmd.run(session)
      end

      it "should send pbx the record command with defaults" do
        pbx.should_receive(:record).with(filename, '01234567890*#', 10)

        cmd = RecordCommand.new 'key', 'desc'
        cmd.run(session)
      end
    end

  end
end