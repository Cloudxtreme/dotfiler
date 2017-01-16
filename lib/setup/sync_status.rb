module Setup

# Mapping of status kinds to their string represenations.
STATUS_KINDS = {
  error: 'error',
  up_to_date: 'up to date',
  backup: 'backup',
  overwrite_data: 'differs'
}

# Current synchronization status of a Task.
class SyncStatus < Struct.new(:name, :kind, :status_msg)
  def self.error(status_msg = nil)
    SyncStatus.new :error, status_msg
  end
end

# Current synchronization status of a Package.
class GroupStatus < Struct.new(:items, :status_msg)
  def kind
    items.map(&:kind).uniq.length == 1 ? items[0].kind : nil
  end
end

module Status

def item_str(item)
  item_str_with_level item, 0
end

def status_str(status)
  kind = STATUS_KINDS[status.kind]
  status.status_msg.nil? ? kind : "#{kind}: #{status.status_msg}"
end

private

def item_str_with_level(item, level)
  name = item.name
  if name.nil?
    if item.children?
      item.map { |subitem| item_str_with_level subitem, level }.join '\n'
    end
  else
    status = item.info
    # ''.ljust(level).
  end
end

end

end