class MySQLPackage < Package
  name 'MySQL'
  platforms [:MACOS, :LINUX]
  restore_to '/usr/local/etc'

  def steps
    file 'my.cnf'
    file 'my.cnf.d'
  end
end