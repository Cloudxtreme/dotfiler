module Setup
  # Mapping of status kinds to their string represenations.
  # @return [Hash<Symbol, String>]
  STATUS_KINDS = {
    error: 'error',
    up_to_date: 'up to date',
    backup: 'needs sync',
    sync: 'needs sync',
    restore: 'needs sync',
    resync: 'needs sync',
    overwrite_data: 'differs'
  }.freeze

  module Status
    def self.get_status_str(status)
      print_nested(status) { |item| [item.status_str, item.items] }
    end

    def self.print_nested(item, &block)
      StringIO.new.tap { |io| print_nested_with_level(item, io, 0, &block) }.string
    end

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

  # Current synchronization status of a {Task}.
  class SyncStatus < Struct.new(:name, :kind, :status_msg)
    def status_str
      kind_str = STATUS_KINDS[kind]
      status_msg.nil? ? "#{name}: #{kind_str}" : "#{name}: #{kind_str}: #{status_msg}"
    end

    def items
      []
    end
  end

  # Current synchronization status of a {Package}.
  class GroupStatus < Struct.new(:name, :items, :status_msg)
    def kind
      items.map(&:kind).uniq.length == 1 ? items[0].kind : nil
    end

    def status_str
      return "#{name}:" if !name.nil? && !name.empty?
    end
  end # module Status
end # module Setup
