# Classes that allow to report the progress of a sync operation.
module Setup

# Null object for a Reporter class
class Reporter
  def start(item)
  end

  def end(item)
  end

  def print_summary
  end
end

# A reporter that logs all messages.
# TODO(drognanar): Allow different operations besides :sync (cleanup! and status!)
class LoggerReporter
  attr_reader :items

  def initialize(logger)
    @items = []
    @logger = logger
  end

  def start(item)
    @items << item
    padded_description = item.description.nil? ? '' : " #{item.description}"
    message = item.children? ? "Syncing#{padded_description}:"
                             : "Syncing#{padded_description}"

    @logger.info message
  end

  def end(item)
  end

  # TODO(drognanar): Remove print_summary from here.
  def print_summary
    if @items.empty?
      @logger << "Nothing to sync\n"
    end
  end
end

end