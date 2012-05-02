module Parsers
  module UserFlowNode
    class Menu < UserCommand
      attr_reader :id, :explanation_message, :options, :timeout, :invalid_message, :end_call_message, :name, :application
      attr_accessor :next

      def initialize application, params
        @id = params['id']
        @name = params['name'] || ''
        @explanation_message = Message.for application, self, :explanation, params['explanation_message']
        @options_message = Message.for application, self, :options, params['options_message']
        @options = params['options'].deep_clone || []
        @root_index = params['root']
        @timeout = params['timeout'] || 5
        @number_of_attempts = params['number_of_attempts'] || 3
        @invalid_message = Message.for application, self, :invalid, params['invalid_message']
        @end_call_message = Message.for application, self, :end_call, params['end_call_message']
        @application = application
        @next = params['next']
      end

      def solve_links_with nodes
        @options.each do |an_option|
          if an_option['next'] && !an_option['next'].is_a?(UserCommand)
            possible_nodes = nodes.select do |a_node|
              a_node.id == an_option['next']
            end
            if possible_nodes.size == 1
              an_option['next'] = possible_nodes.first
            else
              if possible_nodes.size == 0
                raise "There is no command with id #{an_option['next']}"
              else
                raise "There are multiple commands with id #{an_option['next']}: #{possible_nodes.inspect}."
              end
            end
          end
        end
        super
      end

      def is_root?
        @root_index.present?
      end

      def root_index
        @root_index
      end

      def equivalent_flow
        Compiler.parse do |c|
          c.Label @id
          c.Assign "current_step", @id
          c.append @explanation_message.equivalent_flow
          c.Assign "attempt_number#{@id}", '1'
          c.While "attempt_number#{@id} <= #{@number_of_attempts}" do |c|
            c.Capture({finish_on_key: '', timeout: @timeout}.merge(@options_message.capture_flow))
            c.Assign "value_#{@id}", 'digits'
            @options.each do |an_option|
              c.If "digits == '#{an_option['number']}'" do |c|
                c.Trace context_for '"User pressed: " + digits'
                c.append an_option['next'].equivalent_flow if an_option['next']
                c.Goto "end#{@id}"
              end
            end
            c.If "digits != null" do |c|
              c.append @invalid_message.equivalent_flow
              c.Trace context_for '"Invalid key pressed"'
            end
            c.Else do |c|
              c.Trace context_for '"No key was pressed. Timeout."'
            end
            c.Assign "attempt_number#{@id}", "attempt_number#{@id} + 1"
          end
          c.Trace context_for %("Missed input for #{@number_of_attempts} times.")
          c.append @end_call_message.equivalent_flow
          c.End
          c.Label "end#{@id}"
          c.append @next.equivalent_flow if @next
        end
      end
    end
  end
end