# frozen_string_literal: true

require 'dotfiler/edits/steps'

module Dotfiler
  module Edits
    SAMPLE_1 = <<-CODE.freeze
    require 'foo'

    module Mod
      class CD < Import

        def steps
          yield file 'backups'
        end
      end
    end
    CODE

    SAMPLE_2 = <<-CODE
    require 'foo'

    module Mod
      class CD < Import
      end
    end
    CODE

    SAMPLE_3 = <<-CODE
    require 'foo'

    module Mod
      class Test < Import
        def steps
          yield file 'backups'
        end
      end
    end
    CODE

    RSpec.describe AddStep do
      it 'should add a step' do
        expect(AddStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_1)).to eq <<-CODE
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
        expect(AddStep.new('CD', 'yield file \'backups\'').rewrite_str(SAMPLE_1)).to eq SAMPLE_1
      end

      it 'should create a step method if missing' do
        expect(AddStep.new('CD', 'yield file \'backups\'').rewrite_str(SAMPLE_2)).to eq SAMPLE_1
      end

      it 'should not touch a different class' do
        expect(AddStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_3)).to eq SAMPLE_3
      end
    end

    RSpec.describe RemoveStep do
      it 'should remove a step if it exists' do
        expect(RemoveStep.new('CD', 'yield file \'backups\'').rewrite_str(SAMPLE_1)).to eq <<-CODE
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
        expect(RemoveStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_1)).to eq SAMPLE_1
        expect(RemoveStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_2)).to eq SAMPLE_2
      end

      it 'should not remove a step from a different class' do
        expect(RemoveStep.new('CD', 'yield file \'to_add\'').rewrite_str(SAMPLE_3)).to eq SAMPLE_3
      end
    end
  end
end
