require 'setup/platform'

module Setup

RSpec.describe Platform do
  describe '#get_config_value' do
    it 'should get raw values' do
      expect(Platform.get_config_value(12, 'a')).to eq(12)
      expect(Platform.get_config_value('str', 'a')).to eq('str')
    end

    it 'should get dictionaries' do
      config = { a: 12 }
      expect(Platform.get_config_value(config, 'a')).to eq(config)
    end

    it 'should return label results' do
      example_dict = { '<a>' => 12, '<b>' => 15 }
      expect(Platform.get_config_value(example_dict, '<a>')).to eq(12)
      expect(Platform.get_config_value(example_dict, '<b>')).to eq(15)
      expect(Platform.get_config_value(example_dict, '<c>')).to eq(nil)
    end

    it 'should not expand results recursively' do
      value = { '<a>' => 12 }
      example_dict = { '<a>' => value }
      expect(Platform.get_config_value(example_dict, '<a>')).to eq(value)
    end
  end

  describe '#get_platform_from_label' do
    it { expect(Platform.get_platform_from_label '<win>').to eq(:WINDOWS) }
    it { expect(Platform.get_platform_from_label '<macos>').to eq(:MACOS) }
    it { expect(Platform.get_platform_from_label '<linux>').to eq(:LINUX) }
  end
end

end # module Setup
