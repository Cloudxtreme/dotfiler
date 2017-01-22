require 'dotfiler/tasks/package'
require 'dotfiler/templates'

module Dotfiler
  # Helper methods that aid with synchronization process.
  module SyncUtils
    # Creates a backup folder and file structure at +path+.
    # This places the +backups.rb+ and +sync.rb+ files under the
    # current directory.
    #
    # @param logger [Logger]
    # @param io [InputOutput::FileIO]
    # @param force [Boolean] if true then +backups.rb+ and +sync.rb+ files
    #   are created regardless of whether the directory is empty.
    def self.create_backup(path, logger, io, force: false)
      logger << "Creating a backup at \"#{path}\"\n"

      if io.exist?(path) && !io.entries(path).empty? && !force
        logger.warn "Cannot create backup. The folder #{path} already exists and is not empty."
        return
      end

      io.mkdir_p path
      io.write(File.join(path, 'backups.rb'), Dotfiler::Templates.backups)
      io.write(File.join(path, 'sync.rb'), Dotfiler::Templates.sync)
    end

    # Edits a {Tasks::Package} instance defined by +item+.
    #
    # @param item [Package] an item to edit.
    def self.edit_package(item)
      return if item.nil?
      source_path = get_source item
      return unless File.exist? source_path

      editor = ENV['editor'] || 'vim'
      item.ctx.io.system("#{editor} #{source_path}")
    end

    # Finds the location on disk where +item+ was defined.
    #
    # @return [String] location on disk where the {Tasks::Package#steps} was defined.
    def self.get_source(item)
      return nil if (item.nil? || item.class.instance_methods(false).find_index(:steps).nil?)
      item.method(:steps).source_location[0]
    end

    # Walks recursively all items in +item+ (inclusing itself) and executes a provided block.
    #
    # @yieldparam subitem [Task] a subitem of +item+.
    def self.each_child(item, &block)
      return to_enum(__method__, item) unless block_given?
      block.call item
      item.entries.each { |subitem| each_child(subitem, &block) }
    end

    # Looks inside of +item+ and all of its children recursively for a package with +name+.
    #
    # @return [Tasks::Package] a package which matches a +name+ or +nil+ if package not found.
    def self.find_package_by_name(item, name)
      each_child(item).find { |subitem| subitem.name == name && subitem.children? }
    end

    # Looks inside of +item+ and all of its children recursively for a +package+.
    #
    # @return [Tasks::Package] a package which equals to +package+ or +nil+ if package not found.
    def self.find_package(item, package)
      each_child(item).find { |subitem| subitem == package }
    end

    # @return [Array<Package>] a list of all packages that could be enabled.
    #   This includes packages defined by the context that have {Tasks::Task#data?} and
    #   are not yet found within +item+.
    def self.discover_packages(item)
      item.ctx.packages.select do |_, package|
        package.data? && find_package(item, package).nil?
      end.keys
    end

    # @param status [#status_str, #items]
    # @return [String]
    def self.get_status_str(status)
      print_nested(status) { |item| [item.status_str, item.items] }
    end

    # Iterates over a nested tree structure and returns the string.
    # Indents depending on the nesting level.
    #
    # @param item [Object] object to iterate on.
    # @yieldparam subitem [Object] an item for which to return a string.
    # @yieldreturn [[String, Array<Object>]] text for this item, and the list of subitems.
    def self.print_nested(item, &block)
      StringIO.new.tap { |io| print_nested_with_level(item, io, 0, &block) }.string
    end

    # Iterates over a nested tree structure and returns the string.
    # Indents depending on the nesting level.
    #
    # @param item [Object] object to iterate on.
    # @param string_io [StringIO] IO that accumulates the printed output.
    # @param level [Integer] initial indentation of the text.
    # @yieldparam subitem [Object] an item for which to return a string.
    # @yieldreturn [[String, Array<Object>]] text for this item, and the list of subitems.
    def self.print_nested_with_level(item, string_io, level, &block)
      str, subitems = block.call item
      if str.nil? || str.empty?
        subitems.each { |subitem| print_nested_with_level(subitem, string_io, level, &block) }
      else
        string_io << ' ' * 4 * level
        string_io << str << "\n"
        subitems.each { |subitem| print_nested_with_level(subitem, string_io, level + 1, &block) }
      end
    end
  end
end
