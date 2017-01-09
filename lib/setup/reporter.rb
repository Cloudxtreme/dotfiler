# A reporter collects and optionally provides output for executed operations.
module Setup

Event = Struct.new('Event', :op, :item)

# Null object for a Reporter class
class Reporter
  def start(item, op)
  end

  def end(item, op)
  end

  def print_summary
  end
end

# A reporter that logs all messages.
class LoggerReporter
  def initialize(logger)
    @items = []
    @logger = logger
    @ops = { sync: "Syncing" }
  end

  def events(op = nil)
    if op.nil? then @items
    else @items.select { |item| item.op == op }
    end
  end

  def start(item, op)
    @items << Event.new(op, item)
    op_name = @ops[op]
    return if op_name.nil?
    padded_description = item.description.nil? ? '' : " #{item.description}"
    message = item.children? ? "#{op_name}#{padded_description}:"
                             : "#{op_name}#{padded_description}"

    @logger.info message
  end

  def end(item, op)
  end
end

end