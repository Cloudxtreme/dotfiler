module Setup

# Mapping of status kinds to their string represenations.
STATUS_KINDS = {
  error: 'error',
  up_to_date: 'up to date',
  backup: 'needs sync',
  restore: 'needs sync',
  resync: 'needs sync',
  overwrite_data: 'differs'
}

module Status

def self.get_status_str(status)
  StringIO.new.tap { |io| output_status(status, io, 0) }.string
end

private

def self.output_status(status, string_io, level)
  if status.name.nil? or status.name.empty?
    status.items.each { |subitem| self.output_status subitem, string_io, level }
  else
    string_io << ' ' * 4 * level
    string_io << status.status_str << "\n"
    status.items.each { |subitem| self.output_status subitem, string_io, level + 1 }
  end
end

end

# Current synchronization status of a Task.
class SyncStatus < Struct.new(:name, :kind, :status_msg)
  def self.error(status_msg = nil)
    SyncStatus.new :error, status_msg
  end

  def status_str
    kind_str = STATUS_KINDS[kind]
    status_msg.nil? ? "#{name}: #{kind_str}" : "#{name}: #{kind_str}: #{status_msg}"
  end

  def items
    []
  end
end

# Current synchronization status of a Package.
class GroupStatus < Struct.new(:name, :items, :status_msg)
  def kind
    items.map(&:kind).uniq.length == 1 ? items[0].kind : nil
  end

  def status_str
    return "#{name}:"
  end
end

end