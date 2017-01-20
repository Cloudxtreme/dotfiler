require 'setup/logging'
require 'setup/platform'

require 'rspec/logging_helper'
if Setup::Platform::macos? or Setup::Platform::linux?
  require 'simplecov'
  SimpleCov.start
end

ENV['THOR_COLUMNS'] = '120'
ENV['editor'] = 'vim'

RSpec.configure do |config|
  include RSpec::LoggingHelper
  config.capture_log_messages from: 'Setup'

  config.before(:each) do
    LOGGER.level = :verbose
    Logging.appenders['__rspec__'].layout = Logging.layouts.pattern(pattern: '%.1l: %m\n')
    @old_stderr = $stderr
    $stderr = @fake_stderr = StringIO.new
  end

  config.after(:each) do
    stderr = @fake_stderr.string
    stderr.split("\n").each do |line|
      # Filter out variable not initialized warnings coming out of installed gems.
      # But still print any other error.
      vendor_path = File.expand_path File.join(__dir__, '../vendor')
      puts line unless /#{vendor_path}.*warning: instance variable .* not initialized/.match(line)
    end
    $stderr = @old_stderr
  end

  def under_windows
    stub_const 'RUBY_PLATFORM', 'mswin'
    yield
  end

  def under_macos
    stub_const 'RUBY_PLATFORM', 'x86_64-darwin14'
    yield
  end

  def under_linux
    stub_const 'RUBY_PLATFORM', 'arch'
    yield
  end

  def capture_log
    yield
    @log_output.read
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.warnings = true

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.example_status_persistence_file_path = "spec/examples.txt"

  config.disable_monkey_patching!

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  # config.profile_examples = 10

  config.order = :random

  Kernel.srand config.seed
end
