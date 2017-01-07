# Classes for reporting on the progress of a sync operation.
module Setup

class Reporter
  def start(item)
  end

  def end(item)
  end
end

# A reporter that logs all messages.
class LoggerReporter
  # TODO(drognanar): Make this part of Task definition.
  def is_a_task?(item)
    not item.respond_to? :to_a
  end

  def start(item)
    padded_description = item.description.nil? ? '' : " #{item.description}"
    message = is_a_task?(item) ? "Syncing#{padded_description}"
                               : "Syncing#{padded_description}:"

    LOGGER.info message
  end

  def end(item)
  end
end

end