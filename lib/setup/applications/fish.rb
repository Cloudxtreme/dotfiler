module Setup
module Applications

class FishPackage < Setup::Package
  package_name 'Fish'
  platforms [:MACOS, :LINUX]
  restore_to '.config/fish'

  def steps
    yield file 'config.fish'
    yield file 'functions'
  end
end

end
end
