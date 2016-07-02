class PowerShellPackage < Package
  name 'PowerShell'
  platforms [:WINDOWS]
  restore_to '~/Documents/WindowsPowerShell'

  def steps
    file 'Microsoft.PowerShell_profile.ps1'
  end
end