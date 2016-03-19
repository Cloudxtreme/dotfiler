# Static methods to perform platform specific sync.

# TODO: refactor and wire with the rest of the code.
# TODO: possibly convert into a module instead.

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

  def Config.get_platform(platform = nil)
    platform ||= RUBY_PLATFORM 
    case platform
    when /darwin/ then :MAC_OS
    when /cygwin|mswin|mingw|bccwin|wince|emx/ then :WINDOWS
    else :LINUX
    end
  end

  # Gets the machine specific labels.
  # Produces labels for the os, screen resolution.
  def Config.machine_labels(platform = nil)
    os_labels =
      case get_platform(platform)
      when :MAC_OS then ['unix', 'osx', 'mac']
      when :WINDOWS then ['win']
      when :LINUX then ['unix', 'linux']
      end
    os_labels
  end
  
  private
  
  def Config.is_label(name)
    /<.*>/.match name
  end
end

end # module Setup
