# A reporter collects and optionally provides output for executed operations.
module Setup

Event = Struct.new('Event', :op, :item)

# A reporter that collects events generated by tasks.
class Reporter
  def initialize
    @items = []
  end

  def events(op = nil)
    if op.nil? then @items
    else @items.select { |item| item.op == op }
    end
  end

  def start(item, op)
    @items << Event.new(op, item)
  end

  def end(item, op)
  end

  def print_summary
  end
end

# A reporter that logs all messages.
class LoggerReporter < Reporter
  def initialize(logger)
    super()
    @logger = logger
    @ops = { sync: "Syncing" }
  end

  def start(item, op)
    super
    op_name = @ops[op]
    return if op_name.nil? or item.description.nil?
    message = item.children? ? "#{op_name} #{item.description}:"
                             : "#{op_name} #{item.description}"

    @logger.info message
  end

  def end(item, op)
  end
end

end