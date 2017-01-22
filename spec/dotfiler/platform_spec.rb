require 'dotfiler/platform'

module Dotfiler
  RSpec.describe Platform do
    describe '#get_platform' do
      it 'should return the current platform' do
        under_windows { expect(Platform.get_platform).to eq(:WINDOWS) }
        under_macos   { expect(Platform.get_platform).to eq(:MACOS) }
        under_linux   { expect(Platform.get_platform).to eq(:LINUX) }
      end
    end

    describe '#windows?' do
      it 'should return if current platform is windows' do
        under_windows { expect(Platform.windows?).to be true }
        under_macos   { expect(Platform.windows?).to be false }
        under_linux   { expect(Platform.windows?).to be false }
      end
    end

    describe '#linux?' do
      it 'should return if current platform is windows' do
        under_windows { expect(Platform.linux?).to be false }
        under_macos   { expect(Platform.linux?).to be false }
        under_linux   { expect(Platform.linux?).to be true }
      end
    end

    describe '#macos?' do
      it 'should return if current platform is windows' do
        under_windows { expect(Platform.macos?).to be false }
        under_macos   { expect(Platform.macos?).to be true }
        under_linux   { expect(Platform.macos?).to be false }
      end
    end
  end
end
