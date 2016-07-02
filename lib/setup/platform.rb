# Static methods that deal with platform sepcific behavior.

module Setup::Platform
  # Resolves data that can be either a value or a hash from labels to value.
  # For example:
  # get_config_value({ '<win>' => 1, '<mac>' => 2}, '<win>') == 1
  # get_config_value('concrete', '<win>') == 'concrete'
  def self.get_config_value(data, machine_label)
    is_label_hash = (data.is_a?(Hash) and data.keys.all?(&method(:is_label)))
    if is_label_hash
      matching_data = data.select { |label, _| machine_label == label }
      return matching_data.values[0]
    else
      return data
    end
  end

  # Gets the platform of the machine.
  def self.get_platform(platform = nil)
    platform ||= RUBY_PLATFORM
    case platform
    when /darwin/ then :MACOS
    when /cygwin|mswin|mingw|bccwin|wince|emx/ then :WINDOWS
    else :LINUX
    end
  end
  
  def self.windows?(platform = nil)
    get_platform(platform) == :WINDOWS
  end

  def self.macos?(platform = nil)
    get_platform(platform) == :MACOS
  end

  def self.linux?(platform = nil)
    get_platform(platform) == :LINUX
  end
  
  def self.unix?(platform = nil)
    not windows?(platform)
  end

  # Gets the machine specific labels.
  # Produces labels for the os, screen resolution.
  def self.get_platform_from_label(label)
    case label
    when '<macos>' then :MACOS
    when '<win>' then :WINDOWS
    when '<linux>' then :LINUX
    end
  end

  # TODO(drognanar): Deprecate soon after config is removed.
  def self.label_from_platform(platform = nil)
    case self.get_platform platform
    when :MACOS then '<macos>'
    when :WINDOWS then '<cygwin>'
    when :LINUX then '<ubuntu>'
    end
  end

  private

  def self.is_label(name)
    /<.*>/.match name
  end

end # module Setup::Platform
