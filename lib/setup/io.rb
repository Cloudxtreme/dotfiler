# An IO abstraction.
# Used to switch between actual run/dry run/test run.
require 'setup/logging'

require 'fileutils'
require 'forwardable'

module Setup

module InputOutput

class Common_IO
  extend Forwardable
  def_delegators File, :directory?, :exist?, :identical?
  def_delegators Dir, :glob, :entries
  def_delegators IO, :read

  def junction(target_path, link_path)
    shell "cmd /c \"mklink /J \"#{link_path}\" \"#{target_path}\"\""
  end
end

class File_IO < Common_IO
  def_delegators File, :link
  def_delegators FileUtils, :cp_r, :mkdir_p, :mv, :rm_rf

  def shell(command)
    `#{command}`
  end
end

LOGGER = Logging.logger['Setup::InputOutput']

class Dry_IO < Common_IO
  
  def link(source, dest)
    LOGGER.verbose "link source: #{source} dest: #{dest}"
  end

  def cp_r(source, dest)
    LOGGER.verbose "cp_r source: #{source} dest: #{dest}"
  end

  def mkdir_p(path)
    LOGGER.verbose "mkdir_p path: #{path}"
  end

  def rm_rf(path)
    LOGGER.verbose "rm_rf path: #{path}"
  end

  def shell(command)
    LOGGER.verbose command
  end
end

end # module InputOutput

CONCRETE_IO = InputOutput::File_IO.new
DRY_IO = InputOutput::Dry_IO.new

end # module Setup
