# frozen_string_literal: true

require 'erb'

module Dotfiler
  # Helper methods to generate files contents for different templates.
  module Templates
    PACKAGE_TEMPLATE = File.read(File.join(__dir__, 'templates/package.erb')).untaint.freeze
    SYNC_TEMPLATE = File.read(File.join(__dir__, 'templates/sync.erb')).untaint.freeze

    module_function

    # @return [String] content of a +backups.rb+ file based on a template.
    def backups
      bind = binding
      bind.local_variable_set :files, []
      bind.local_variable_set :packages, []
      bind.local_variable_set :package_class_name, 'MyBackup'
      bind.local_variable_set :package_name, ''
      ERB.new(PACKAGE_TEMPLATE, 2, '>').result(bind)
    end

    # @return [String] content of a +<package_name>.rb+ file based on a template.
    def package(package_name, files: [], packages: [])
      package_name ||= ''
      bind = binding
      bind.local_variable_set :package_class_name, "#{package_name.capitalize}Package"
      ERB.new(PACKAGE_TEMPLATE, 2, '>').result(bind)
    end

    # @return [String] content of a +sync.rb+ file based on a template.
    def sync
      ERB.new(SYNC_TEMPLATE, 2, '>').result(binding)
    end
  end
end
