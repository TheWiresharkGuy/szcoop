$local:_ScoopRoot = $_ScoopRoot; if( -not $_ScoopRoot ) { $_ScoopRoot = 
#
# Can be run as-is by running:
#
# > iex (new-object net.webclient).downloadstring('https://lksz.me/szcoop')
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
######### BEGIN ALIAS SECTION #########
$local:installAliases = [ordered]@{}
$installAliases['autocomplete-on' ] = 'Get-Module -ListAvailable $env:SCOOP\modules\* | Where-Object Name -eq scoop-completion | Import-Module'
$installAliases['autocomplete-off'] = 'Get-Module scoop-completion | Remove-Module'
# alias to create an objects based export:
$installAliases['export-ps'       ] = 'param([string[]]$filter,[switch]$WithPath) $local:update = [ordered]@{}; $local:in = ""; $a | % { $local:line = $_; switch (($line -split " ")[0]){ "Updates" { $in = "update" } "" { if( $in -ne "" ) { $local:u = [ordered]@{}; $_u = ($line -split ":"); $u.Name = $_u[0].Trim(); $u.Current, $u.Available = ($_u[1].Trim() -split " -> "); Invoke-Expression "`$$in[''$($u.Name)''] = [PSCustomObject]`$u"; } } default {$in = ""} } }; scoop export | sls "^(.+)\W\(v:(.+)\)( \*global\*)? \[(.+)\]$" |% { $local:p=$_.matches.groups; if($filter -and $p[1].value -notin $filter){return}; $local:r = [ordered]@{ Scope=if($p[3].value){"Global"}else{"Local"}; Bucket=$p[4].value; AppName=$p[1].value; Version=$p[2].value }; if( $update.Count -gt 1 ) { $r.UpdateAvailable = $update.Values | Where-Object Name -eq $r.AppName | Select-Object -ExpandProperty Available }; if($WithPath){ $r.AppPath=$(($local:tmp = scoop info $p[1].value) | sls "Installed:" | % { Join-Path (Split-Path -Parent (($tmp[$_.LineNumber].Replace(" *global*","")).Trim())) "current" }) }; [PSCustomObject]($r) }'
$installAliases['export-ps-ex'    ] = 'param([string[]]$filter,[switch]$WithPath) scoop export-ps -filter:$filter -WithPath:$WithPath | sort Scope,AppName'
$installAliases['alias-list'      ] = 'scoop alias list *>&1 | Out-String -Stream | sls "^[^ ]+" | % { $_.matches.Value }'
# alias, for cleaner output of refresh:
$installAliases['refresh'         ] = 'Write-Host -Foreground DarkGreen "Refreshing scoop..."; (scoop update *>&1 | Out-Null); scoop status'
$installAliases['alias-update'    ] = '$local:szcoopSrc = $szcoopSrc; if( -not $szcoopSrc ) { $szcoopSrc = (new-object net.webclient).downloadstring("https://lksz.me/szcoop") }; Write-Host -ForegroundColor DarkGreen "Refreshing aliases..."; scoop alias-list | % { scoop alias rm $_ }; Invoke-Expression ($szcoopSrc -split ("ALIAS SECTION " + "#"))[1]; Write-Host -ForegroundColor DarkGreen "Aliases updated:"; scoop alias-list'

# add aliases defined above, making sure it is overwritten by any other alias already existing.
$installAliases.Keys | % { $(scoop alias rm $_ *>&1 | out-null); scoop alias add $_ $installAliases[$_] }
######### END ALIAS SECTION #########

# activate autocomplete (with alias defined above)
scoop autocomplete-on

## prepare PowerShell default profile:
# Setup SCOOP_GLOBAL if not set (most commonly, because no Admin access)
# Activate scoop-completion in default profile
$local:_profilePath = $profile.CurrentUserAllHosts
if( $IsAdmin ) { $_profilePath = $profile.AllUsersAllHosts }
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
