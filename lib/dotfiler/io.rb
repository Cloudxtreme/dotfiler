# An IO abstraction.
# Used to switch between actual run/dry run/test run.
require 'dotfiler/logging'
require 'dotfiler/platform'

require 'fileutils'
require 'forwardable'

module Dotfiler
  module InputOutput
    # @api private
    # Common set of IO methods.
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

    # This class executes both read and write IO instructions.
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

    # This class executes read IO instructions, but only logs write IO instructions.
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
  end

  CONCRETE_IO = InputOutput::FileIO.new
  DRY_IO = InputOutput::DryIO.new
end
