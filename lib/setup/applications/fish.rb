class FishPackage < Setup::Package
  package_name 'Fish'
  platforms [:MACOS, :LINUX]
  restore_to '.config/fish'

  def steps
    file 'config.fish'
    file 'functions'
  end
end