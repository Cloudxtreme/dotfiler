lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'setup/version'

Gem::Specification.new do |s|
  s.name = 'setup'
  s.version = Setup::VERSION
  s.authors     = %w(Drognanar)
  s.email       = 'drognanar@gmail.com'

  s.summary     = 'Settings manager'
  s.description = 'Gem to manage setup'
  s.license     = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = ''
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  s.files       = Dir.glob('{lib, bin}/**/*')
  s.bindir      = 'bin'
  s.executables = ['setup']
  s.require_paths = ['lib']

  s.add_dependency 'safe_yaml', ['~> 1.0']
  s.add_dependency 'thread', ['~> 0.1']
  s.add_dependency 'rspec', ['~> 3.2']
  s.add_dependency 'attr_extras', ['~> 4.4']
end
