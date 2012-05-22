require 'spec_helper'

module Parsers
  module UserFlowNode
    describe Record do

      let(:call_flow) { double('call_flow', :id => 5) }

      it "should compile to an equivalent flow" do
        record = Record.new call_flow, 'id' => 1,
          'type' => 'record',
          'name' => 'Record Step',
          'explanation_message' => {
            "name" => "Explanation message",
            "type" => "text"
          },
          'confirmation_message' => {
            "name" => "Confirmation message",
            "type" => "text"
          },
          'timeout' => 7,
          'stop_key' => '#'

        record.equivalent_flow.first.should eq(
          Compiler.parse do
            Label 1
            Assign "current_step", 1
            Trace call_flow_id: 5, step_id: 1, step_name: 'Record Step', store: %("Record message. Download link: " + record_url(1))
            Say "Explanation message"
            Record 1, 'Record Step', {:stop_keys => '#', :timeout => 7}
            Say "Confirmation message"
          end.first
        )
      end

    end
  end
end