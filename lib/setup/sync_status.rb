class SyncStatus
  attr_reader :kind
  attr_reader :status_msg
  def initialize(kind, status_msg = nil)
    @kind = kind
    @status_msg = status_msg
  end
end