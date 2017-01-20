# TODO(drognanar): Can we have a more lightweight abstraction?
# TODO(drognanar): Instead of abstracting IO abstract some classes into DRY and FILE?

# An IO abstraction.
# Used to switch between actual run/dry run/test run.
require 'setup/logging'
require 'setup/platform'

require 'fileutils'
require 'forwardable'

module Setup
  module InputOutput
    class CommonIO
      extend Forwardable
      def_delegators File, :directory?, :exist?, :identical?
      def_delegators Dir, :glob, :entries
      def_delegators IO, :read

      def junction(target_path, link_path)
        if Platform.windows?
          shell "cmd /c \"mklink /J \"#{link_path}\" \"#{target_path}\"\""
        else
          link target_path, link_path
        end
      end
    end

    class FileIO < CommonIO
      def_delegators File, :write
      def_delegators FileUtils, :cp_r, :mkdir_p, :mv, :rm_rf
      def_delegators Kernel, :system

      def dry
        false
      end

      def link(target_path, link_path)
        if Platform.macos? || Platform.linux?
          File.symlink target_path, link_path
        elsif Platform.windows?
          File.link target_path, link_path
        end
      end

      def shell(command)
        `#{command}`
      end
    end

    class DryIO < CommonIO
      def dry
        true
      end

      def write(source, content)
        LOGGER.info "> echo \"#{content}\" > #{source}"
      end

      def mv(source, dest)
        LOGGER.info "> mv \"#{source}\" \"#{dest}\""
      end

      def link(source, dest)
        LOGGER.info "> ln -s \"#{source}\" \"#{dest}\""
      end

      def cp_r(source, dest)
        LOGGER.info "> cp -r \"#{source}\" \"#{dest}\""
      end

      def mkdir_p(path)
        LOGGER.info "> mkdir -p \"#{path}\""
      end

      def rm_rf(path)
        LOGGER.info "> rm -rf \"#{path}\""
      end

      def shell(command)
        LOGGER.info "> #{command}"
      end

      def system(command)
        LOGGER.info "> #{command}"
      end
    end
  end # module InputOutput

  CONCRETE_IO = InputOutput::FileIO.new
  DRY_IO = InputOutput::DryIO.new
end # module Setup
