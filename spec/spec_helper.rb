require 'setup/logging'
require 'setup/platform'

require 'rspec/logging_helper'
if Setup::Platform::unix?
  require 'simplecov'
  SimpleCov.start
end

ENV["THOR_COLUMNS"] = '120'

RSpec.configure do |config|
  include RSpec::LoggingHelper
  config.capture_log_messages from: 'Setup'

  config.before(:each) do
    LOGGER.level = :verbose
    Logging.appenders['__rspec__'].layout = Logging.layouts.pattern(pattern: '%.1l: %m\n')
  end
  
  def under_windows
    stub_const 'RUBY_PLATFORM', 'mswin'
    yield
  end
  
  def under_osx
    stub_const 'RUBY_PLATFORM', 'x86_64-darwin14'
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

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.example_status_persistence_file_path = "spec/examples.txt"

  config.disable_monkey_patching!

  config.warnings = true

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
