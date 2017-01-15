module Setup

# Base class for all tasks and packages.
class Task
  extend Platform
  include Platform

  attr_reader :skip_reason, :ctx

  def initialize(ctx)
    @skip_reason = nil
    @ctx = ctx
  end

  # Marks this tasks to skip executing any operations and stores the reason
  # why the task was skipped.
  # @param string reason a reason why the Task was skipped.
  def skip(reason = '')
    @skip_reason = reason
  end

  # Returns true if this task has subtasks that should be executed.
  # Returns false if this task is a leaf task.
  def children?
    defined? each
  end

  # Name to show for the task when reporting execution progress.
  def description
    nil
  end

  # Returns true if a task should be executed.
  # Returns false if a task should be skipped.
  def should_execute
    @skip_reason.nil? and ((not children?) or entries.empty? or any? { |item| item.should_execute })
  end

  def sync!
    raise NotImplementedError 'Should be implemented by a subclass'
  end

  def cleanup!
    raise NotImplementedError 'Should be implemented by a subclass'
  end

  private

  # Reports a particular operation and executes a provided code block
  # if a task should execute.
  def execute(op, item=self)
    ctx.reporter.start item, op
    yield if should_execute
  ensure
    ctx.reporter.end item, op
  end
end

end
