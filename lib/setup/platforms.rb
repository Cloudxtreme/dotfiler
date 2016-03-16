# Static methods to perform platform specific sync.

# TODO: detect labels such as win, lin, mac
# TODO: add configuration functions to simplify config management.

module Setup

class Config
  # Resolves data that can be either a value or a hash from labels to value.
  def Config.get_config_value(data, label)
    is_label_hash = (data.is_a?(Hash) and data.keys.all?(&method(:is_label)))
    if is_label_hash and data.key? label
      return data[label]
    elsif is_label_hash
      return nil
    else
      return data
    end
  end

  def Config.has_matching_label(machine_label, task_labels)
    task_labels.empty? or task_labels.include? machine_label
  end

  def Config.is_label(name)
    /<.*>/.match name
  end

  def Config.get_platform
    case RUBY_PLATFORM
      when /darwin/
        return :MAC_OS
      when /cygwin|mswin|mingw|bccwin|wince|emx/
        return :WINDOWS
      else
        return :LINUX
    end
  end

  # Gets the machine specific labels.
  # Produces labels for the os, screen resolution.
  def Config.machine_labels
    labels = []

    if get_platform == :MAC_OS
      labels << 'unix' << 'osx' << 'max'
    elsif get_platform == :LINUX
      labels << 'unix' << 'linux'
    else
      labels << 'win'
    end
    labels
  end
end

end # module Setup
