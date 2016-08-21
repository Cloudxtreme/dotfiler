require 'erb'

module Setup

PACKAGE_TEMPLATE = "class <%= package_name.capitalize %>Package < Setup::Package
  package_name '<%= package_name.capitalize %>'

  def steps
<% for file in files %>
    file '<%= file %>'
<% end %>
  end
end
"

APPLICATIONS_TEMPLATE = "<% for application in applications %>
<%= application.name.split('::').last %> = <%= application.name %>

<% end %>
"

def self.get_package(package_name, files)
  ERB.new(PACKAGE_TEMPLATE, 2, '>').result(binding)
end

def self.get_applications(applications)
  ERB.new(APPLICATIONS_TEMPLATE, 2, '>').result(binding)
end

end