module Setup
module Applications

class MySQLPackage < Setup::Package
  package_name 'MySQL'
  platforms [:MACOS, :LINUX]
  restore_to '/usr/local/etc'

  def steps
    yield file 'my.cnf'
    yield file 'my.cnf.d'
  end
end

end
end
