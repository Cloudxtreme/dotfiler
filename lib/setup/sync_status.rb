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

# TODO: Use a string builder to build the status_str

module Status

# Returns a stirng representation of a status including subitems.
def status_str
  status_str_with_level 0
end

private

# Returns a string representation of a status excluding subitems.
def status_str_single
  return "#{name}:" if kind.nil?
  kind_str = STATUS_KINDS[kind]

  status_msg.nil? ? "#{name}: #{kind_str}" : "#{name}: #{kind_str}: #{status_msg}"
end

end

# Current synchronization status of a Task.
class SyncStatus < Struct.new(:name, :kind, :status_msg)
  include Status

  def self.error(status_msg = nil)
    SyncStatus.new :error, status_msg
  end

  private

  def status_str_with_level(level)
    status_str_single
  end
end

# Current synchronization status of a Package.
class GroupStatus < Struct.new(:name, :items, :status_msg)
  include Status

  def kind
    items.map(&:kind).uniq.length == 1 ? items[0].kind : nil
  end

  private

  def status_str_with_level(level)
    if name.nil?
      items.map { |subitem| subitem.status_str_with_level level }.join '\n'
    else
      subitem_status_str = items.map { |subitem| subitem.status_str_with_level(level + 1) }.join '\n'
      status_str_single
    end
  end
end

end