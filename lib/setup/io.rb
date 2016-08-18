# An IO abstraction.
# Used to switch between actual run/dry run/test run.
require 'setup/logging'
require 'setup/platform'

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
    if Platform::windows?
      shell "cmd /c \"mklink /J \"#{link_path}\" \"#{target_path}\"\""
    else
      link target_path, link_path
    end
  end
end

class File_IO < Common_IO
  def_delegators FileUtils, :cp_r, :mkdir_p, :mv, :rm_rf
  def_delegators Kernel, :system
  
  def dry
    false
  end
  
  def link(target_path, link_path)
    if Platform::macos? or Platform::linux?
      File.symlink target_path, link_path
    elsif Platform::windows?
      File.link target_path, link_path
    end
  end

  def shell(command)
    `#{command}`
  end
end

class Dry_IO < Common_IO
  def dry
    true
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

CONCRETE_IO = InputOutput::File_IO.new
DRY_IO = InputOutput::Dry_IO.new

end # module Setup
