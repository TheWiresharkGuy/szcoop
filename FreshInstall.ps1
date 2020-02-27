#
### To run this function, copy-paste the following line into a PowerShell session
#
# iwr 'https://lksz.me/szcoop' | iex
# Install-Szcoop -ScoopRoot 'C:\Scoop'
#
### or just
# Install-Szcoop
#
### In case the IWR command fails try the code below.
# iex $(New-Object System.Net.WebClient).DownloadString('https://lksz.me/szcoop')
#
### TLS 1.2 might need to be allowed by the following:
# [Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
#
### An additional utility funciton is included, in case you're running an old version of PowerShell:
# Install-PowerShellCore #[-TargetPath 'C:\_\bin\pwsh'] [-DontStartPwsh] [-ForceFresh] [-Cleanup]
#

function Install-Szcoop {
    param ( [string]$ScoopRoot = 'C:\Scoop' )

    $local:_ScoopRoot = $ScoopRoot;

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

    Remove-Item Function:Install-Szcoop,Function:Install-PowerShellCore -ErrorAction SilentlyContinue

    scoop bucket add extras
    # Add scoop-completion bucket, followed by installation
    scoop bucket add scoop-completion https://github.com/Moeologist/scoop-completion
    scoop install scoop-completion
    ######### BEGIN ALIAS SECTION #########
    $local:installAliases = [ordered]@{}
    $installAliases['alias-update'    ] = '$local:szcoopSrc = $szcoopSrc; if( -not $szcoopSrc ) { $szcoopSrc = (new-object net.webclient).downloadstring("https://lksz.me/szcoop") }; Write-Host -ForegroundColor DarkGreen "Refreshing aliases..."; scoop alias-list | % { scoop alias rm $_ }; Invoke-Expression ($szcoopSrc -split ("ALIAS SECTION " + "#"))[1]; Write-Host -ForegroundColor DarkGreen "Aliases updated:"; scoop alias-list'
    # function update-scoopalias { iex $installAliases['alias-update'] }; update-scoopalias; update-scoopalias; # select this line with the 2 above to only update/refresh the aliases.
    $installAliases['autocomplete-on' ] = 'Get-Module -ListAvailable $env:SCOOP\modules\* | Where-Object Name -eq scoop-completion | Import-Module'
    $installAliases['autocomplete-off'] = 'Get-Module scoop-completion | Remove-Module'
    # alias to create an objects based export:
    $installAliases['export-ps'       ] = 'param([string[]]$filter,[switch]$WithPath) $local:update = [ordered]@{}; $local:in = ""; $(scoop status *>&1) | % { $local:line = $_; switch (($line -split " ")[0]){ "Updates" { $in = "update" } "" { if( $in -ne "" ) { $local:u = [ordered]@{}; $_u = ($line -split ":"); $u.Name = $_u[0].Trim(); $u.Current, $u.Available = ($_u[1].Trim() -split " -> "); Invoke-Expression "`$$in[''$($u.Name)''] = [PSCustomObject]`$u"; } } default {$in = ""} } }; scoop export | sls "^(.+)\W\(v:(.+)\)( \*global\*)? \[(.+)\]$" |% { $local:p=$_.matches.groups; if($filter -and $p[1].value -notin $filter){return}; $local:r = [ordered]@{ Scope=if($p[3].value){"Global"}else{"Local"}; Bucket=$p[4].value; AppName=$p[1].value; Version=$p[2].value }; if( $update.Count -gt 1 ) { $r.UpdateAvailable = $update.Values | Where-Object Name -eq $r.AppName | Select-Object -ExpandProperty Available }; if($WithPath){ $r.AppPath=$(($local:tmp = scoop info $p[1].value) | sls "Installed:" | % { Join-Path (Split-Path -Parent (($tmp[$_.LineNumber].Replace(" *global*","")).Trim())) "current" }) }; [PSCustomObject]($r) }'
    $installAliases['export-ps-ex'    ] = 'scoop export-ps | sort Scope,AppName'
    $installAliases['alias-list'      ] = 'scoop alias list *>&1 | Out-String -Stream | sls "^[^ ]+" | % { $_.matches.Value }'
    # alias, for cleaner output of refresh:
    $installAliases['refresh'         ] = 'Write-Host -Foreground DarkGreen "Refreshing scoop..."; (scoop update *>&1 | Out-Null); scoop export-ps | Where-Object "UpdateAvailable" -ne $null | Sort-Object Scope,AppName | ft -AutoSize'

    ## prepare PowerShell default profile:
    # Setup SCOOP_GLOBAL if not set (most commonly, because no Admin access)
    # Activate scoop-completion in default profile
    $installAliases['setup-profile'  ] = @"   
    `$local:_profilePath = `$profile.CurrentUserAllHosts
    if( `$IsAdmin ) { `$_profilePath = `$profile.AllUsersAllHosts }
    if( -not (Test-Path `$_profilePath) -or ((Get-Content -Path `$_profilePath | out-string ) -notmatch 'autocomplete-on' ) ) { 
        if( -not (Test-Path `$_profilePath) ) { New-Item -ItemType Directory `$(Split-Path -Parent `$_profilePath) -Force | Out-Null }
        Add-Content -Path `$_profilePath -Value @('',
                ('if( -not `$env:SCOOP ) { `$env:SCOOP = "' + `$(Join-Path $env:SCOOP_GLOBAL '_') + '`$(`$env:USERNAME)" }'),
                'if( -not `$env:SCOOP_GLOBAL ) { `$env:SCOOP_GLOBAL = Split-Path -Parent `$env:SCOOP }',
                '',
                'if( -not `$(`$env:Path -match `$(`$env:SCOOP_GLOBAL -replace "\\","\\")) ) {',
                '  `$env:Path = "`$(Join-Path `$env:SCOOP shims);`$(Join-Path `$env:SCOOP_GLOBAL shims);`$(`$env:Path)"',
                '}',
                '',
                'scoop autocomplete-on'
            )
    }
"@

    # add aliases defined above, making sure it is overwritten by any other alias already existing.
    $installAliases.Keys | % { $(scoop alias rm $_ *>&1 | out-null); scoop alias add $_ $installAliases[$_] }
    ######### END ALIAS SECTION #########

    # with aliases defined above: activate autocomplete, setup profile
    scoop autocomplete-on
    scoop setup-profile

    # update buckets
    scoop update

    # update and cleanup all packages
    scoop update *
    scoop cleanup *

    scoop checkup
}


function Install-PowerShellCore {
param(
    [string]$TargetPath = 'C:\_\bin\pwsh',
    [switch]$DontStartPwsh,
    [switch]$ForceFresh,
    [switch]$Cleanup
)
    try {
        Write-Host -ForegroundColor DarkYellow "Downloading PowerShell Core manifest from main scoop.sh bucket..."
        [Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $local:wc = $(New-Object System.Net.WebClient);
        $local:PwshScoopJson = $wc.DownloadString('https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/pwsh.json') | ConvertFrom-Json

        $local:pwshUrl = $PwshScoopJson.architecture.'64bit'.url
        $local:pwshArchive = $(Join-Path $env:TEMP $(Split-Path -Leaf $pwshUrl))

        if( Test-Path $pwshArchive ) {
            Write-Host -ForegroundColor DarkYellow "Removing already existing file [$pwshArchive]..."
            Remove-Item -Path $pwshArchive -Force | Out-Null
        }
        Write-Host -ForegroundColor DarkYellow "Downloading PowerShell Core zip release..."
        $wc.DownloadFile( $pwshUrl, $pwshArchive )
        Unblock-File $pwshArchive

        if( $(Test-Path $TargetPath) -and $ForceFresh ) {
            Write-Host -ForegroundColor DarkYellow "Removing pre-existing directory [$TargetPath]..."
            Remove-Item -Path $TargetPath -Force -Recurse | Out-Null
        }

        Write-Host -ForegroundColor DarkYellow "Extract downloaded zip into target location..."
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($pwshArchive, $TargetPath)

        if( -not $DontStartPwsh ) {
            Write-Host -ForegroundColor DarkYellow "Starting PowerShell Core..."
            Start-Process $(Join-Path $TargetPath pwsh.exe)
        }

        if( $Cleanup ) {
            if( Test-Path $pwshArchive ) {
                Write-Host -ForegroundColor DarkYellow "Removing downloaded [$pwshArchive]..."
                Remove-Item -Path $pwshArchive -Force | Out-Null
            }
        }

        Write-Host -ForegroundColor DarkYellow "All done."
        Write-Host -NoNewline -ForegroundColor DarkCyan "ZIP downloaded from: "; Write-Host -ForegroundColor Cyan "$pwshUrl"
        if( -not $Cleanup ) {
            Write-Host -NoNewline -ForegroundColor DarkCyan "Temp ZIP File (ok to remove): "; Write-Host -ForegroundColor Cyan "$pwshArchive"
        }
        Write-Host -NoNewline -ForegroundColor DarkCyan "PowerShell core can be run from: "; Write-Host -ForegroundColor Cyan "$TargetPatht"
    } finally {
    }
}