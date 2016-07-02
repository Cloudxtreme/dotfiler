# Static methods that deal with platform sepcific behavior.

module Setup::Platform

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

end # module Setup::Platform
