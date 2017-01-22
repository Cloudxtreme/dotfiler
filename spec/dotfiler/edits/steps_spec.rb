# frozen_string_literal: true

require 'dotfiler/edits/steps'

SAMPLE_1 = <<-CODE.strip_heredoc
require 'foo'

module Mod
  class CD < Import

    def steps
      yield file 'backups'
    end
  end
end
CODE

SAMPLE_2 = <<-CODE.strip_heredoc
require 'foo'

module Mod
  class CD < Import
  end
end
CODE

SAMPLE_3 = <<-CODE.strip_heredoc
require 'foo'

module Mod
  class Test < Import
    def steps
      yield file 'backups'
    end
  end
end
CODE

RSpec.describe Edits::AddStep do
  it 'should add a step' do
    expect(Edits::AddStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_1)).to eq <<-CODE.strip_heredoc
      require 'foo'

      module Mod
        class CD < Import

          def steps
            yield file 'backups'
            yield file 'to_add'
          end
        end
      end
    CODE
  end

  it 'should not add an existing step' do
    expect(Edits::AddStep.new('CD', 'yield file \'backups\'').rewrite_str(SAMPLE_1)).to eq SAMPLE_1
  end

  it 'should create a step method if missing' do
    expect(Edits::AddStep.new('CD', 'yield file \'backups\'').rewrite_str(SAMPLE_2)).to eq SAMPLE_1
  end

  it 'should not touch a different class' do
    expect(Edits::AddStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_3)).to eq SAMPLE_3
  end
end

RSpec.describe Edits::RemoveStep do
  it 'should remove a step if it exists' do
    expect(Edits::RemoveStep.new('CD', 'yield file \'backups\'').rewrite_str(SAMPLE_1)).to eq <<-CODE.strip_heredoc
      require 'foo'

      module Mod
        class CD < Import

          def steps
          end
        end
      end
    CODE
  end

  it 'should not remove a non existing step' do
    expect(Edits::RemoveStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_1)).to eq SAMPLE_1
    expect(Edits::RemoveStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_2)).to eq SAMPLE_2
  end

  it 'should not remove a step from a different class' do
    expect(Edits::RemoveStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_3)).to eq SAMPLE_3
  end
end
