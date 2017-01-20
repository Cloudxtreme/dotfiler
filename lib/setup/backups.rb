# Allows to discover backups instances under a given machine.
require 'setup/package'
require 'setup/package_template'

require 'pathname'
require 'yaml'
require 'yaml/store'

module Setup

class InvalidConfigFileError < Exception
  attr_reader :path, :inner_exception

  def initialize(path, inner_exception)
    @path = path
    @inner_exception = inner_exception
  end
end

# A single backup directory present on a local computer.
# Discovered packages are packages which are not loaded by backup but have data.
# TODO(drognanar): Get rid of backup_packages_path and the #backup method.
class Backup < ItemPackage
  BACKUP_PACKAGES_PATH = '_packages'

  def backup_packages_path
    ctx.backup_path BACKUP_PACKAGES_PATH
  end
end

# TODO(drognanar): Slowly deprecate BackupManager.
# TODO(drognanar): Having to deal with another global config file makes things more confusing.
class BackupManager < ItemPackage
  DEFAULT_CONFIG_PATH = File.expand_path '~/setup.yml'

  def initialize(ctx = nil, store = nil)
    super(ctx)
    @store = store
  end

  # Loads backup manager configuration and backups it references.
  def BackupManager.from_config(ctx)
    store = YAML::Store.new(DEFAULT_CONFIG_PATH)
    BackupManager.new(ctx, store)
  end

  def load_backups!
    @backup_paths = @store.transaction(true) { |store| store.fetch('backups', []) }
    logger.verbose "Loading backups: #{@backup_paths}"
    @items = @backup_paths.map(&method(:backup))
  rescue PStore::Error => e
    raise InvalidConfigFileError.new @store.path, e
  end
end

module Backups

def self.create_backup(path, logger, io, force: false)
  logger << "Creating a backup at \"#{path}\"\n"

  if io.exist?(path) and not io.entries(path).empty? and not force
    logger.warn "Cannot create backup. The folder #{path} already exists and is not empty."
    return
  end

  io.mkdir_p path
  io.write(File.join(path, 'backups.rb'), Setup::Templates::backups)
  io.write(File.join(path, 'sync.rb'), Setup::Templates::sync)
end

def self.edit_package(item, io)
  return if item.nil?
  source_path = get_source item

  if File.exist? source_path
    editor = ENV['editor'] || 'vim'
    io.system("#{editor} #{source_path}")
  end
end

def self.get_source(item)
  return nil if item.nil?
  item.method(:steps).source_location[0]
end

def self.each_child(item, &block)
  return to_enum(__method__, item) unless block_given?
  block.call item
  item.entries.each { |subitem| each_child(subitem, &block) }
end

def self.find_package_by_name(item, name)
  each_child(item).find { |subitem| subitem.name == name && subitem.children? }
end

def self.find_package(item, package)
  each_child(item).find { |subitem| subitem == package }
end

def self.discover_packages(item)
  item.ctx.packages.select do |package_name, package|
    package.has_data && find_package(item, package).nil?
  end.keys
end

end

end # module Setup
