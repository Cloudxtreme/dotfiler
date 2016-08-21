class NginxPackage < Setup::Package
  package_name 'Nginx'
  platforms [:MACOS, :LINUX]
  restore_to '/usr/local/etc'

  def steps
    file 'nginx'
  end
end