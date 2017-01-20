require 'setup/task'

module Setup
  RSpec.describe Task do
    let(:task) { Task.new nil }

    it 'should throw an error on sync!' do
      expect { task.sync! }.to raise_error(NotImplementedError)
    end

    it 'should throw an error on cleanup!' do
      expect(task.cleanup!).to be nil
    end
  end
end