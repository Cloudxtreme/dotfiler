# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dotfiler/about'
require 'dotfiler/platform'

Gem::Specification.new do |spec|
  spec.name        = Dotfiler::About::APP_NAME
  spec.version     = Dotfiler::About::VERSION
  spec.authors     = %w(Drognanar)
  spec.email       = 'drognanar@gmail.com'

  spec.summary     = 'Settings manager'
  spec.description = 'Gem to manage setup'
  spec.license     = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = ''
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushespec.'
  end

  spec.files         = Dir.glob('{lib, exe}/**/*')
  spec.bindir        = 'exe'
  spec.executables   = ['dotfiler']
  spec.require_paths = ['lib']

  spec.metadata['allowed_push_host'] = 'http://localhost'

  spec.add_dependency 'highline', ['~> 1.7']
  spec.add_dependency 'logging', ['~> 2.1']
  spec.add_dependency 'parser', ['~> 2.3']
  spec.add_dependency 'thor', ['~> 0.19']

  spec.add_development_dependency 'awesome_print', ['~> 1.6']
  spec.add_development_dependency 'pry', ['~> 0.10']
  spec.add_development_dependency 'rspec', ['~> 3.4']
  spec.add_development_dependency 'yard', ['~> 0.9']
  if Dotfiler::Platform.linux? || Dotfiler::Platform.osx?
    spec.add_development_dependency 'simplecov', ['~> 0.11']
  end
end
