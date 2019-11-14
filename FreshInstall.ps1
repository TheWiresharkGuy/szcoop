$local:_ScoopRoot = $_ScoopRoot; if( -not $_ScoopRoot ) { $_ScoopRoot = 
#
# Can be run as-is by running:
#
# > iex (new-object net.webclient).downloadstring('https://code.lksz.me/lksz/szcoop/raw/branch/master/FreshInstall.ps1')
#
###################################################################################
# Set this to the root of Scoop
'C:\Scoop'
##########

###################################################################################
# The code below will install scoop in a 'Szkolnik optimized/recommended' setup
# Here's what is does:
# 1. Setup scoop environment (SCOOP and SCOOP_GLOBAL), if possible make persistant
# 2. Install scoop
# 3. Install base packages for optimal scoop behavior
# 4. Add extras and scoop-autocomplete buckets
# 5. Intstall autocomplete and assign aliases to switch it on / off
# 6. Initialize profile to activate auto-completion
# 7. Upgrade cleanup and checkup
#
}

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

& scoop install $useGlobal 7zip git innounp dark aria2

scoop bucket add extras
# Add scoop-completion bucket, followed by installation
scoop bucket add scoop-completion https://github.com/liuzijing97/scoop-completion
scoop install scoop-completion
$local:aliasList = scoop | Out-String -Width 17; # instead of scoop alias list which outputs to out-warning when empty
'autocomplete-off','autocomplete-on','export-ps','refresh' | Where-Object { $aliasList -match $_ } | ForEach-Object { scoop alias rm $_ |  out-null }
scoop alias add autocomplete-on  'Get-Module -ListAvailable $env:SCOOP\modules\* | Where-Object Name -eq scoop-completion | Import-Module'
scoop alias add autocomplete-off 'Get-Module scoop-completion | Remove-Module'
# add a scoop alias, to create a collection of objects:
scoop alias add export-ps 'param([string[]]$filter,[switch]$WithPath)
 scoop export | sls ''^(.+)\W\(v:(.+)\)( \*global\*)? \[(.+)\]$'' |% {
     $local:p=$_.matches.groups;
     if($filter -and $p[1].value -notin $filter){return};
     $local:r = [ordered]@{
         AppName=$p[1].value;
         Version=$p[2].value;
         Scope=if($p[3].value){"Global"}else{"Local"};
         Bucket=$p[4].value
     };
     if($WithPath){
         $r.AppPath=$(($local:tmp = scoop info $p[1].value) | sls "Installed:" | % { Join-Path (Split-Path -Parent (($tmp[$_.LineNumber].Replace(" *global*","")).Trim())) "current" })
     };
     [PSCustomObject]($r)
 }'
scoop alias add refresh "Write-Host -Foreground DarkGreen 'Refreshing scoop...'; Start-Process -NoNewWindow -Wait cmd -ArgumentList '/c','scoop','update','>NUL'; scoop status"
scoop autocomplete-on

## prepare PowerShell default profile:
# Setup SCOOP_GLOBAL if not set (most commonly, because no Admin access)
# Activate scoop-completion in default profile
$local:_profilePath = $profile.CurrentUserAllHosts
if( $IsAdmin ) { _profilePath = $profile.AllUsersAllHosts }
if( -not (Test-Path $_profilePath) -or ((Get-Content -Path $_profilePath | out-string ) -notmatch 'scoop-completion' ) ) { 
    New-Item -ItemType Directory $(Split-Path -Parent $_profilePath) -Force | Out-Null
    Add-Content -Path $_profilePath -Value "`nif( -not `$env:SCOOP_GLOBAL ) { `$env:SCOOP_GLOBAL = Split-Path -Parent `$env:SCOOP }"
    Add-Content -Path $_profilePath -Value "`nscoop autocomplete-on"
}
# update buckets
scoop update

# update and cleanup all packages
scoop update *
scoop cleanup *

scoop checkup
