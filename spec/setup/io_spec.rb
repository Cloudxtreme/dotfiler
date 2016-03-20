# IO unit tests. These tests mock the File instances and thus cannot be run in parallel.
require 'setup/io'

module Setup

module AssertDelegate
# Asserts that an instance delegates a method call.
def assert_delegates(instance, delegate, method, *args)
  expect(delegate).to receive(method).with(*args).and_return nil
  instance.send method, *args
end
end

RSpec.describe 'Common_IO' do
  include AssertDelegate

  it 'delegates readonly io operations' do
    assert_delegates DRY_IO, File, :directory?, 'path'
    assert_delegates DRY_IO, File, :exist?, 'path'
    assert_delegates DRY_IO, File, :identical?, 'path1', 'path2'
    assert_delegates DRY_IO, Dir, :glob, 'path'
    assert_delegates DRY_IO, Dir, :entries, 'path'
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
    expect(CONCRETE_IO).to receive(:`).with('echo hello world').once
    CONCRETE_IO.shell 'echo hello world'
  end

  it 'sends junction for execution to shell' do
    expect(CONCRETE_IO).to receive(:shell).with('cmd /c "mklink /J "path2" "path1""')
    CONCRETE_IO.junction 'path1', 'path2'
  end
end

RSpec.describe 'Dry_IO' do
  include AssertDelegate

  it 'prints all write io operations' do
    expect(capture(:stdout) { DRY_IO.link 'path1', 'path2' }).to eq("link source: path1 dest: path2\n")
    expect(capture(:stdout) { DRY_IO.cp_r 'path1', 'path2' }).to eq("cp_r source: path1 dest: path2\n")
    expect(capture(:stdout) { DRY_IO.mkdir_p 'path' }).to eq("mkdir_p path: path\n")
    expect(capture(:stdout) { DRY_IO.rm_rf 'path' }).to eq("rm_rf path: path\n")
    expect(capture(:stdout) { DRY_IO.junction 'path1', 'path2' }).to eq("cmd /c \"mklink /J \"path2\" \"path1\"\"\n")
    expect(capture(:stdout) { DRY_IO.shell 'echo hello world' }).to eq("echo hello world\n")
  end
end

end # module Setup
