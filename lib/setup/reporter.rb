# Classes for reporting on the progress of a sync operation.
module Setup

class Reporter
  def start(item)
  end

  def end(item)
  end

  def print_summary
  end
end

# A reporter that logs all messages.
class LoggerReporter
  attr_reader :items

  def initialize
    @items = []
    @level = 0
  end

  def start(item)
    @level += 1
    @items << item
    padded_description = item.description.nil? ? '' : " #{item.description}"
    message = item.children? ? "Syncing#{padded_description}:"
                             : "Syncing#{padded_description}"

    LOGGER.info message
  end

  def end(item)
    # Print the summary when all operations complete.
    @level -= 1
  end

  def print_summary
    if @level == 0 and @items.empty?
      LOGGER << "Nothing to sync\n"
    end
  end
end

end