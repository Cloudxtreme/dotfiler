# Allows to discover backups instances under a given machine.
require 'setup/package'
require 'setup/package_template'

module Setup

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
