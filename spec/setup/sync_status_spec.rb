require 'setup/sync_status'

module Setup

RSpec.describe SyncStatus do
  it 'should be a simple struct' do
    status = SyncStatus.new 'name', :up_to_date, 'message'
    expect(status.name).to eq('name')
    expect(status.kind).to eq(:up_to_date)
    expect(status.status_msg).to eq('message')
  end
end

RSpec.describe GroupStatus do
  it 'should be a simple struct' do
    status = GroupStatus.new [], 'message'
    expect(status.items).to eq([])
    expect(status.status_msg).to eq('message')
  end

  describe '#kind' do
    it 'should include subitem status if all are equal' do
      status1 = SyncStatus.new 'name1', :up_to_date
      status2 = SyncStatus.new 'name2', :up_to_date
      status = GroupStatus.new [status1, status2], 'message'
      expect(status.items).to eq([status1, status2])
      expect(status.kind).to eq(:up_to_date)
    end

    it 'should return nil if not all subitem status are not equal' do
      status1 = SyncStatus.new 'name1', :up_to_date
      status2 = SyncStatus.new 'name2', :error
      status = GroupStatus.new [status1, status2], 'message'
      expect(status.items).to eq([status1, status2])
      expect(status.kind).to eq(nil)
    end
  end
end

RSpec.describe Status do
  describe '#status_str' do
  end
end

end