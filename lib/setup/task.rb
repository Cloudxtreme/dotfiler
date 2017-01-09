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

  def skip(reason = '')
    @skip_reason = reason
  end

  def children?
    false
  end

  def description
    nil
  end

  def should_execute
    return @skip_reason.nil?
  end

  def cleanup
    []
  end

  def execute(op, item=self)
    ctx.reporter.start item, op
    return yield
  ensure
    ctx.reporter.end item, op
  end
end

end