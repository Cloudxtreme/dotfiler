require 'setup/edits/rewriter_utils'

require 'parser'

module Setup
  module Edits
    class AddStep < Parser::Rewriter
      include RewriterUtils

      def initialize(backup_name, step)
        @backup_name = backup_name
        @step = step
      end

      def on_class(node)
        return super unless node.location.name.source == @backup_name
        steps = node.body.find { |child| child.type == :def && child.location.name.source == 'steps' }
        if steps.nil?
          # This package does not define a steps method. Define one.
          insert_above node.location.end, "
def steps
  #{@step}
end"
          return
        end

        # If a step is not defined by the steps method add it.
        if steps.body.find_index(ast(@step)).nil?
          insert_above steps.location.end, @step
        end
      end
    end

    class RemoveStep < Parser::Rewriter
      include RewriterUtils

      def initialize(backup_name, step)
        @backup_name = backup_name
        @step = step
      end

      def on_class(node)
        return super unless node.location.name.source == @backup_name
        steps = node.body.find { |child| child.type == :def && child.location.name.source == 'steps' }
        return if steps.nil?
        instruction = steps.body.find { |child| child == ast(@step) }
        return if instruction.nil?

        # Extend the line_range to include the newline character.
        range = line_range(instruction.location.expression)
        range = range.resize range.size + 1
        remove range
      end
    end
  end # module Edits
end # module Setup
