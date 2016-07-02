# Static methods that deal with platform sepcific behavior.

module Setup::Platform
  # Resolves data that can be either a value or a hash from labels to value.
  # For example:
  # get_config_value({ '<win>' => 1, '<mac>' => 2}, ['<win>']) == 1
  # get_config_value('concrete', ['<win>']) == 'concrete'
  def self.get_config_value(data, machine_labels)
    is_label_hash = (data.is_a?(Hash) and data.keys.all?(&method(:is_label)))
    if is_label_hash
      matching_data = data.select { |label, _| has_matching_label(machine_labels, [label]) }
      return matching_data.values[0]
    else
      return data
    end
  end

  # Checks if the two sets of labels have an intersection.
  # has_matching_label(['<win>', '<osx>'], ['<win>']) == true
  def self.has_matching_label(machine_labels, task_labels)
    task_labels.empty? or Set.new(task_labels).intersect?(Set.new(machine_labels))
  end

  # Gets the platform of the machine.
  def self.get_platform(platform = nil)
    platform ||= RUBY_PLATFORM
    case platform
    when /darwin/ then :MAC_OS
    when /cygwin|mswin|mingw|bccwin|wince|emx/ then :WINDOWS
    else :LINUX
    end
  end
  
  def self.windows?(platform = nil)
    get_platform(platform) == :WINDOWS
  end

  def self.macos?(platform = nil)
    get_platform(platform) == :MAC_OS
  end

  def self.linux?(platform = nil)
    get_platform(platform) == :LINUX
  end
  
  def self.unix?(platform = nil)
    not windows?(platform)
  end

  # Gets the machine specific labels.
  # Produces labels for the os, screen resolution.
  def self.machine_labels(platform = nil)
    case get_platform(platform)
    when :MAC_OS then ['<unix>', '<osx>', '<mac>']
    when :WINDOWS then ['<win>']
    when :LINUX then ['<unix>', '<linux>']
    end
  end

  private

  def self.is_label(name)
    /<.*>/.match name
  end

end # module Setup::Platform
