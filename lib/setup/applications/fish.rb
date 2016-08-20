class FishPackage < Setup::Package
  name 'Fish'
  platforms [:MACOS, :LINUX]
  restore_to '.config/fish'

  def steps
    file 'config.fish'
    file 'functions'
  end
end