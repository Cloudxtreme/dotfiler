require 'setup/io'

module Setup

module AssertDelegate
def assert_delegates(instance, delegate, method, *args)
  expect(delegate).to receive(method).with(*args).and_return nil
  instance.send method, *args
end

def capture_stdout(&block)
  old_stdout = $stdout
  $stdout = StringIO.new
  block.call
  $stdout.string
rescue
  $stdout = old_stdout
end
end

RSpec.describe 'Common_IO' do
  include AssertDelegate

  it 'delegates readonly io operations' do
    assert_delegates DRY_IO, File, :directory?, 'path'
    assert_delegates DRY_IO, File, :exist?, 'path'
    assert_delegates DRY_IO, File, :identical?, 'path1', 'path2'
    assert_delegates DRY_IO, Dir, :glob, 'path'
    assert_delegates DRY_IO, IO, :read, 'path'
  end
end


RSpec.describe 'File_IO' do
  include AssertDelegate

  it 'delegates all write io operations' do
    assert_delegates CONCRETE_IO, File, :link, 'path1', 'path2'
    assert_delegates CONCRETE_IO, FileUtils, :cp_r, 'path1', 'path2'
    assert_delegates CONCRETE_IO, FileUtils, :mkdir_p, 'path1', 'path2'
    assert_delegates CONCRETE_IO, FileUtils, :mv, 'path1', 'path2'
    assert_delegates CONCRETE_IO, FileUtils, :rm_rf, 'path1', 'path2'
  end

  it 'sends junction for execution to shell' do
    expect(CONCRETE_IO).to receive(:shell).with('cmd /c "mklink /J "path2" "path1""')
    CONCRETE_IO.junction 'path1', 'path2'
  end
end

RSpec.describe 'Dry_IO' do
  include AssertDelegate

  it 'prints all write io operations' do
    expect($stdout).to receive(:puts).with('link source: path1 dest: path2')
    DRY_IO.link 'path1', 'path2'

    expect($stdout).to receive(:puts).with('cp_r source: path1 dest: path2')
    DRY_IO.cp_r 'path1', 'path2'

    expect($stdout).to receive(:puts).with('mkdir_p path: path')
    DRY_IO.mkdir_p 'path'

    expect($stdout).to receive(:puts).with('rm_rf path: path')
    DRY_IO.rm_rf 'path'

    expect($stdout).to receive(:puts).with('cmd /c "mklink /J "path2" "path1""')
    DRY_IO.junction 'path1', 'path2'
  end
end

end # module Setup
