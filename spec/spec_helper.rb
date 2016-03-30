require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
  def capture_stdio(stdout: true, stderr: true)
    result = {}
    begin
      $stdout = StringIO.new if stdout
      $stderr = StringIO.new if stderr
      block_result = yield
      result[:stdout] = $stdout.string if stdout
      result[:stderr] = $stderr.string if stderr
      result[:result] = block_result
    ensure
      $stdout = STDOUT if stdout
      $stderr = STDERR if stderr
    end

    result
  end

  def capture(stream, &block)
    if stream == :stdout then capture_stdio(stdout: true) { block.call }[:stdout]
    elsif stream == :stderr then capture_stdio(stderr: true) { block.call }[:stderr]
    end
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
