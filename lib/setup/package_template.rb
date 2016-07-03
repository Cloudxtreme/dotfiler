require 'erb'

module Setup

PACKAGE_TEMPLATE = "
class <%= package_name.capitalize %>Package < Setup::Package
    name '<%= package_name %>'

    def steps
<% for file in files %>
        file '<%= file %>'
<% end %>
    end
end"

def self.get_package(package_name, files)
  ERB.new(PACKAGE_TEMPLATE, 2, '>').result(binding)
end

end