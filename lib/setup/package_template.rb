require 'erb'

module Setup
module Templates

PACKAGE_TEMPLATE = File.read(File.join(__dir__, 'templates/package.erb')).untaint
APPLICATIONS_TEMPLATE = File.read(File.join(__dir__, 'templates/applications.erb')).untaint

module_function

def package(package_name, files)
  ERB.new(PACKAGE_TEMPLATE, 2, '>').result(binding)
end

def applications(applications)
  ERB.new(APPLICATIONS_TEMPLATE, 2, '>').result(binding)
end

end
end