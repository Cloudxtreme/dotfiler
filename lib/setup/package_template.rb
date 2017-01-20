require 'erb'

module Setup
  module Templates
    APPLICATIONS_TEMPLATE = File.read(File.join(__dir__, 'templates/applications.erb')).untaint
    BACKUPS_TEMPLATE = File.read(File.join(__dir__, 'templates/backups.erb')).untaint
    PACKAGE_TEMPLATE = File.read(File.join(__dir__, 'templates/package.erb')).untaint
    SYNC_TEMPLATE = File.read(File.join(__dir__, 'templates/sync.erb')).untaint

    module_function

    def applications(applications)
      ERB.new(APPLICATIONS_TEMPLATE, 2, '>').result(binding)
    end

    def backups
      ERB.new(BACKUPS_TEMPLATE, 2, '>').result(binding)
    end

    def package(package_name, files)
      # TODO(drognanar): Deal with case sensitivity somewhere
      ERB.new(PACKAGE_TEMPLATE, 2, '>').result(binding)
    end

    def sync
      ERB.new(SYNC_TEMPLATE, 2, '>').result(binding)
    end
  end # module Templates
end # module Setup
