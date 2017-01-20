module Setup
  # Method helpers that detect the current machine's OS and run scripts
  # specificically on a particular OS.
  module Platform
    extend self

    # Returns the current machine's OS.
    # @param [string] platform the string representation of current ruby platform.
    def get_platform(platform = nil)
      platform ||= RUBY_PLATFORM
      case platform
      when /darwin/ then :MACOS
      when /cygwin|mswin|mingw|bccwin|wince|emx/ then :WINDOWS
      else :LINUX
      end
    end

    # Returns true if the current machine is running windows.
    # @param [string] platform the string representation of current ruby platform.
    def windows?(platform = nil)
      get_platform(platform) == :WINDOWS
    end

    # Returns true if the current machine is running osx.
    # @param [string] platform the string representation of current ruby platform.
    def osx?(platform = nil)
      get_platform(platform) == :MACOS
    end
    alias macos? osx?

    # Returns true if the current machine is running linux.
    # @param [string] platform the string representation of current ruby platform.
    def linux?(platform = nil)
      get_platform(platform) == :LINUX
    end

    # Executes a block of code if a machine is currently running under windows.
    # @example
    #   under_windows { puts 'This code will only execute under windows' }
    def under_windows
      yield if windows?
    end

    # Executes a block of code if a machine is currently running under osx.
    # @example
    #   under_osx { puts 'This code will only execute under osx' }
    def under_osx
      yield if osx?
    end
    alias under_macos under_osx

    # Executes a block of code if a machine is currently running under linux.
    # @example
    #   under_linux { puts 'This code will only execute under linux' }
    def under_linux
      yield if linux?
    end
  end # module Platform
end # module Setup
