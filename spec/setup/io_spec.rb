# IO unit tests. These tests mock the File instances and thus cannot be run in parallel.
require 'setup/io'
require 'setup/platform'

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

# Redefine the symlink method in order so that it can be mocked for under_macos context.
# Otherwise rspec throws the NotImplementedException.
if Platform::windows?
  begin
    old_verbose, $VERBOSE = $VERBOSE, nil
    def File.symlink(path1, path2)
      raise 'Not supported on windows'
    end
  ensure
    $VERBOSE = old_verbose
  end
end

RSpec.describe 'File_IO' do
  include AssertDelegate

  it 'delegates all write io operations' do
    assert_delegates CONCRETE_IO, FileUtils, :cp_r, 'path1', 'path2'
    assert_delegates CONCRETE_IO, FileUtils, :mkdir_p, 'path1', 'path2'
    assert_delegates CONCRETE_IO, FileUtils, :mv, 'path1', 'path2'
    assert_delegates CONCRETE_IO, FileUtils, :rm_rf, 'path1', 'path2'
    assert_delegates CONCRETE_IO, Kernel, :system, 'work'
    expect(CONCRETE_IO).to receive(:`).with('echo hello world').once
    CONCRETE_IO.shell 'echo hello world'
  end
  
  it 'is not dry' do
    expect(CONCRETE_IO.dry).to be false
  end
  
  it 'hardlinks on windows' do
    expect(File).to receive(:link).with('path1', 'path2')
    under_windows { CONCRETE_IO.link 'path1', 'path2' }
  end
  
  it 'symlinks on unix' do
    expect(File).to receive(:symlink).with('path1', 'path2')
    under_macos { CONCRETE_IO.link 'path1', 'path2' }
  end

  it 'sends junction for execution to shell' do
    expect(CONCRETE_IO).to receive(:shell).with('cmd /c "mklink /J "path2" "path1""')
    under_windows { CONCRETE_IO.junction 'path1', 'path2' }
  end
  
  it 'symlinks on unix' do
    expect(File).to receive(:symlink).with('path1', 'path2')
    under_macos { CONCRETE_IO.junction 'path1', 'path2' }
  end
end

RSpec.describe 'Dry_IO' do
  include AssertDelegate

  it 'prints all write io operations' do
    expect(capture_log { DRY_IO.link 'path1', 'path2' }).to eq("I: > ln -s \"path1\" \"path2\"\n")
    expect(capture_log { DRY_IO.cp_r 'path1', 'path2' }).to eq("I: > cp -r \"path1\" \"path2\"\n")
    expect(capture_log { DRY_IO.mv 'path1', 'path2' }).to eq("I: > mv \"path1\" \"path2\"\n")
    expect(capture_log { DRY_IO.mkdir_p 'path' }).to eq("I: > mkdir -p \"path\"\n")
    expect(capture_log { DRY_IO.rm_rf 'path' }).to eq("I: > rm -rf \"path\"\n")
    expect(capture_log { DRY_IO.shell 'echo hello world' }).to eq("I: > echo hello world\n")
    expect(capture_log { DRY_IO.system 'echo hello world' }).to eq("I: > echo hello world\n")
  end
  
  it 'prints junction on windows' do
    stub_const 'RUBY_PLATFORM', 'mswin'
    expect(capture_log { DRY_IO.junction 'path1', 'path2' }).to eq("I: > cmd /c \"mklink /J \"path2\" \"path1\"\"\n")
  end
  
  it 'prints symlink on unix' do
    stub_const 'RUBY_PLATFORM', 'x86_64-darwin14'
    expect(capture_log { DRY_IO.junction 'path1', 'path2' }).to eq("I: > ln -s \"path1\" \"path2\"\n")
  end
  
  it 'is dry' do
    expect(DRY_IO.dry).to be true
  end
end

end # module Setup
