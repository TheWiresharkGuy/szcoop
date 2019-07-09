# Set this to the root of Scoop
$local:_ScoopRoot = 'C:\_\bin\_Scoop'

################################################################################
# The code below will install scoop in a 'Szkolnik optimized/recommended' setup

$local:currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$local:IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$local:useGlobal = ''
if( $IsAdmin ) { $useGlobal = '--global' }

$env:SCOOP_GLOBAL=$_ScoopRoot
$env:SCOOP="$_ScoopRoot\_$(split-path $env:USERPROFILE -Leaf)"
[environment]::setEnvironmentVariable('SCOOP', $env:SCOOP, 'User')

if( $IsAdmin ) {
    [environment]::setEnvironmentVariable('SCOOP_GLOBAL',$env:SCOOP_GLOBAL,'Machine')
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1
}

iex (new-object net.webclient).downloadstring('https://get.scoop.sh')

scoop install $useGlobal 7zip git innounp dark aria2

scoop bucket add extras
scoop update

scoop update *
scoop cleanup *

scoop checkup