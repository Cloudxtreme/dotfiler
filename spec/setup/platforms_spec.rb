require 'setup/platforms'

module Setup

RSpec.describe 'Config' do
  describe 'get_config_value' do
    it 'should get raw values' do
      expect(Config.get_config_value(12, 'a')).to eq(12)
      expect(Config.get_config_value('str', 'a')).to eq('str')
    end

    it 'should get dictionaries' do
      expect(Config.get_config_value({a: 12}, 'a')).to eq({a: 12})
    end

    it 'should return label results' do
      example_dict = {'<a>' => 12, '<b>' => 15}
      expect(Config.get_config_value(example_dict, '<a>')).to eq(12)
      expect(Config.get_config_value(example_dict, '<b>')).to eq(15)
      expect(Config.get_config_value(example_dict, '<c>')).to eq(nil)
    end

    it 'should not expand results recursively' do
      value = {'<a>' => 12}
      example_dict = {'<a>' => value}
      expect(Config.get_config_value(example_dict, '<a>')).to eq(value)
    end
  end
end

end # module Setup
