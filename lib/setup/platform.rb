# Method helpers that detect the current machine's OS
# and run scripts specificically on a particular OS.
module Setup
  module Platform
    module_function

    # Returns the current machine's OS.
    # @param string The string representation of current ruby platform.
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

    def under_windows
      yield if windows?
    end

    def under_macos
      yield if macos?
    end

    def under_linux
      yield if linux?
    end
  end # module Platform
end # module Setup
