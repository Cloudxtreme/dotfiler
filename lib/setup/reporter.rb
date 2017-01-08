# Classes that allow to report the progress of a sync operation.
module Setup

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
  attr_reader :items

  def initialize(logger)
    @items = []
    @logger = logger
    @ops = { sync: "Syncing", clean: "Cleaning" }
  end

  def start(item, op)
    @items << item
    op_name = @ops[op]
    padded_description = item.description.nil? ? '' : " #{item.description}"
    message = item.children? ? "#{op_name}#{padded_description}:"
                             : "#{op_name}#{padded_description}"

    @logger.info message
  end

  def end(item, op)
  end
end

end