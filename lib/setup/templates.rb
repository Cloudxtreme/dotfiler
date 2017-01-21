# frozen_string_literal: true

require 'erb'

module Setup
  # Helper methods to generate files contents for different templates.
  module Templates
    APPLICATIONS_TEMPLATE = File.read(File.join(__dir__, 'templates/applications.erb')).untaint.freeze
    BACKUPS_TEMPLATE = File.read(File.join(__dir__, 'templates/backups.erb')).untaint.freeze
    PACKAGE_TEMPLATE = File.read(File.join(__dir__, 'templates/package.erb')).untaint.freeze
    SYNC_TEMPLATE = File.read(File.join(__dir__, 'templates/sync.erb')).untaint.freeze

    module_function

    # @return [String] content of an +applications.rb+ file based on a template.
    def applications(applications)
      ERB.new(APPLICATIONS_TEMPLATE, 2, '>').result(binding)
    end

    # @return [String] content of a +backups.rb+ file based on a template.
    def backups
      ERB.new(BACKUPS_TEMPLATE, 2, '>').result(binding)
    end

    # @return [String] content of a +<package_name>.rb+ file based on a template.
    def package(package_name, files)
      # TODO(drognanar): Deal with case sensitivity somewhere
      ERB.new(PACKAGE_TEMPLATE, 2, '>').result(binding)
    end

    # @return [String] content of a +sync.rb+ file based on a template.
    def sync
      ERB.new(SYNC_TEMPLATE, 2, '>').result(binding)
    end
  end # module Templates
end # module Setup
