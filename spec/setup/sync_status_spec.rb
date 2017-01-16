require 'setup/sync_status'

module Setup

RSpec.describe SyncStatus do
  it 'should be a simple struct' do
    status = SyncStatus.new 'name', :up_to_date, 'message'
    expect(status.name).to eq('name')
    expect(status.kind).to eq(:up_to_date)
    expect(status.status_msg).to eq('message')
  end

  describe '#status_str' do
    it 'should return a status string' do
      status = SyncStatus.new 'name', :up_to_date
      expect(status.status_str).to eq('name: up to date')
    end

    context 'when status_msg not nil' do
      it 'should display status_msg' do
        status = SyncStatus.new 'name', :error, 'error message'
        expect(status.status_str).to eq('name: error: error message')
      end
    end
  end
end

RSpec.describe GroupStatus do
  it 'should be a simple struct' do
    group = GroupStatus.new 'name', [], 'message'
    expect(group.items).to eq([])
    expect(group.status_msg).to eq('message')
  end

  describe '#kind' do
    it 'should include subitem status if all are equal' do
      status1 = SyncStatus.new 'name1', :up_to_date
      status2 = SyncStatus.new 'name2', :up_to_date
      group = GroupStatus.new 'name', [status1, status2], 'message'
      expect(group.items).to eq([status1, status2])
      expect(group.kind).to eq(:up_to_date)
    end

    it 'should return nil if not all subitem status are not equal' do
      status1 = SyncStatus.new 'name1', :up_to_date
      status2 = SyncStatus.new 'name2', :error
      group = GroupStatus.new 'name', [status1, status2], 'message'
      expect(group.items).to eq([status1, status2])
      expect(group.kind).to eq(nil)
    end
  end

  describe '#status_str' do
    it 'should print item if no subitems' do
      group = GroupStatus.new 'group', []
      expect(group.status_str).to eq('group:')
    end

    it 'should print itself and subitems' do
      pending 'Not implemented yet'
      status1 = SyncStatus.new 'name1', :up_to_date
      status2 = SyncStatus.new 'name2', :error, 'error message'
      group = GroupStatus.new 'group', [status1, status2]
      expect(group.status_str).to eq(
'group:
    name1: up to date
    name2: error: error message')
    end

    it 'should handle subgroups' do
      pending 'Not implemented yet'
      status1 = SyncStatus.new 'name1', :up_to_date
      status2 = SyncStatus.new 'name2', :error, 'error message'
      status3 = SyncStatus.new 'name3', :sync
      group1 = GroupStatus.new 'group1', [status1, status2]
      group = GroupStatus.new 'group', [group1, status3]
      expect(group.status_str).to eq(
'group:
    group1:
        name1: up to date
        name2: error: error message
    name3: sync')
    end
  end
end

end