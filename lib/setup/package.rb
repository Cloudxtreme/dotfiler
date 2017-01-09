require 'setup/task'

require 'json'

module Setup

# A package is a collection Tasks.
class Package < Task
  include Enumerable

  DEFAULT_RESTORE_DIR = File.expand_path '~/'

  def self.restore_dir(value)
    self.class_eval "def restore_dir; #{JSON.dump(File.expand_path(value, '~/')) if value}; end"
  end

  def self.package_name(value)
    self.class_eval "def name; #{JSON.dump(value) if value}; end"
  end

  def self.platforms(platforms)
    self.class_eval "def platforms; #{platforms if platforms}; end"
  end

  package_name ''

  def description
    "package #{name}"
  end

  def each
    steps { |step| yield step }
  end

  def steps
  end

  def children?
    true
  end

  def initialize(parent_ctx)
    ctx = parent_ctx
      .with_backup_dir(File.join(parent_ctx.backup_path, name))
      .with_restore_dir(defined?(restore_dir) ? restore_dir : Package::DEFAULT_RESTORE_DIR)
    super(ctx)

    if defined?(platforms) and (not platforms.empty?) and (not platforms.include? Platform.get_platform)
      skip 'Unsupported platform'
    end
  end

  def has_data
    any? { |sync_item| sync_item.info.status.kind != :error }
  end

  def sync!
    return unless should_execute
    execute(:sync) { each { |sync_item| sync_item.sync! } }
  end

  def cleanup!
    return unless should_execute
    each { |item| item.cleanup! }
  end
end

# A package which contains a field with the list of tasks that it should execute.
class ItemPackage < Package
  attr_accessor :items

  def initialize(ctx)
    super(ctx)
    @items = []
  end

  def steps
    items.each { |item| yield item }
  end
end

end # module Setup
