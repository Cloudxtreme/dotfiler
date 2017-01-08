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

  def should_execute
    return @skip_reason.nil?
  end

  def execute
    ctx.reporter.start self
    yield
  ensure
    ctx.reporter.end self
  end
end

end