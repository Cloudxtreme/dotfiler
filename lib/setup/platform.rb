# Static methods that deal with platform sepcific behavior.

module Setup::Platform

module_function

# Gets the platform of the machine.
def get_platform(platform = nil)
  platform ||= RUBY_PLATFORM
  case platform
  when /darwin/ then :MACOS
  when /cygwin|mswin|mingw|bccwin|wince|emx/ then :WINDOWS
  else :LINUX
  end
end

def windows?(platform = nil)
  get_platform(platform) == :WINDOWS
end

def macos?(platform = nil)
  get_platform(platform) == :MACOS
end

def linux?(platform = nil)
  get_platform(platform) == :LINUX
end

def under_windows(&block)
  block.call if windows?
end

def under_macos(&block)
  block.call if macos?
end

def under_linux(&block)
  block.call if linux?
end

end # module Setup::Platform
