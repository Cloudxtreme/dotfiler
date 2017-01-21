require 'setup/tasks/task'

module Setup
  module Tasks
    # A {ProcTask} is a task that executes a provided code block within a context.
    # It provides an API that allows to create anonymous tasks.
    class ProcTask < Task
      attr_reader :name

      def initialize(name, ctx, &block)
        super(ctx)
        @name = name
        @block = block
      end

      # (see Task#sync!)
      def sync!
        block.call ctx
      end
    end
  end
end
