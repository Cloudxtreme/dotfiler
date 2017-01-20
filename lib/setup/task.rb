require 'setup/sync_status'

module Setup
  # Base class for all tasks and packages.
  # A {Task} is a single step performed during synchronization.
  # It takes a {SyncContext} with common options and needs to implement the following methods:
  # * {#sync!} what should be executed when a synchronization is being executed.
  #
  # A {Task} can also implement the following methods:
  #
  # * {#status} the status of synchronization.
  #   Gives a more customized message when running {Cli::Program#status}.
  #   Also, {Cli::Package#discover} will not list packages which return the +:error+ status.
  #
  # * {#cleanup!} what should be cleaned up when a task is run.
  #   Without this if a task creates any backup files a user will have to clean them manually.
  class Task
    extend Platform
    extend Forwardable
    include Platform

    attr_reader :skip_reason, :ctx
    def_delegators :@ctx, :io, :logger, :reporter, :packages

    def initialize(ctx)
      @skip_reason = nil
      @ctx = ctx
    end

    # Marks this tasks to skip executing any operations and stores the reason
    # why the task was skipped.
    # @param reason [string] a reason why the {Task} was skipped.
    # @example
    #   task = Task.new SyncContext.new
    #   task.skip "Don't execute"
    #   task.should_execute # false
    # @note one skipped a {Task} cannot be unskipped.
    def skip(reason = '')
      @skip_reason = reason
    end

    # @return [Boolean] whether or not a task has children.
    # Returns +true+ if this task has subtasks that should be executed.
    # Returns +false+ if this task is a leaf task.
    def children?
      defined? each
    end

    # @return [Array<Task>] a list of subtasks that should be executed.
    def entries
      []
    end

    # @return [Boolean] whether or not any tasks has anything to sync.
    def data?
      should_execute && (children? ? (any? { |sync_item| sync_item.status.kind != :error }) : status.kind != :error)
    end

    # Name to show for the task when reporting execution progress.
    def description
      nil
    end

    # @return [Boolean] whether or not a task should be executed.
    # Returns +true+ if a task should be executed.
    # Returns +false+ if a task should be skipped.
    def should_execute
      if children? then (@skip_reason.nil? && (entries.empty? || any?(&:should_execute)))
      else @skip_reason.nil?
      end
    end

    # @return [String] string representation of this {Task} used by the {LoggerReporter}.
    # @see {LoggerReporter}
    def description
      ''
    end

    # Performs the synchronization operation.
    def sync!
      raise NotImplementedError, 'Should be implemented by a subclass'
    end

    # Performs the cleanup operation.
    def cleanup!; end

    # @return [SyncStatus] the status of synchronization.
    # @see {SyncStatus}
    def status
      SyncStatus.new name, :sync
    end

    private

    # Reports a particular operation and executes a provided code block
    # if a task should execute.
    def execute(op, item = self)
      reporter.start op, item
      yield if should_execute
    ensure
      reporter.end op, item
    end
  end
end # module Setup
