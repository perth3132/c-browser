[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$KeepUserData,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CWebBrowser')
)

$ErrorActionPreference = 'Stop'
$AppName = 'C Browser'
$Version = '1.0.0'
$RuntimeVersion = '152.0.4191.62'
$Repo = 'https://raw.githubusercontent.com/perth3132/c-browser/main'
$RuntimeUrl = "https://www.nuget.org/api/v2/package/WebView2.Runtime.X64/$RuntimeVersion"
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CWebBrowser'
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'C Browser.lnk'
$StartMenuFolder = Join-Path ([Environment]::GetFolderPath('Programs')) 'C Browser'
$UserData = Join-Path $env:LOCALAPPDATA 'CWebBrowser\UserData'

function Stop-InstalledBrowser {
    $browserPath = Join-Path $InstallRoot 'browser.exe'
    Get-Process -Name browser -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $browserPath } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

function Remove-InstalledBrowser {
    Stop-InstalledBrowser
    Remove-Item $DesktopShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item $StartMenuFolder -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $UninstallKey -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $KeepUserData) {
        Remove-Item $UserData -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "$AppName was uninstalled."
    if ($KeepUserData) { Write-Host "User data kept at $UserData" }
}

function New-Shortcut([string]$Path) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = Join-Path $InstallRoot 'browser.exe'
    $shortcut.WorkingDirectory = $InstallRoot
    $shortcut.Description = $AppName
    $shortcut.Save()
}

function Install-Browser {
    $tempRoot = Join-Path $env:TEMP "C-Browser-Setup-$([Guid]::NewGuid().ToString('N'))"
    $runtimeArchive = Join-Path $tempRoot 'WebView2.Runtime.X64.nupkg'
    $runtimeZip = Join-Path $tempRoot 'WebView2.Runtime.X64.zip'
    $runtimeExtract = Join-Path $tempRoot 'runtime'
    try {
        New-Item -ItemType Directory -Force -Path $InstallRoot,$tempRoot | Out-Null
        Copy-Item $PSCommandPath (Join-Path $InstallRoot 'C-Browser-Setup.ps1') -Force
        Invoke-WebRequest "$Repo/browser.exe" -OutFile (Join-Path $InstallRoot 'browser.exe')
        Invoke-WebRequest "$Repo/WebView2Loader.dll" -OutFile (Join-Path $InstallRoot 'WebView2Loader.dll')
        Invoke-WebRequest $RuntimeUrl -OutFile $runtimeArchive
        Copy-Item $runtimeArchive $runtimeZip -Force
        Expand-Archive $runtimeZip -DestinationPath $runtimeExtract -Force
        $runtimeSource = Get-ChildItem $runtimeExtract -Directory -Recurse |
            Where-Object { $_.Name -eq 'WebView2' } | Select-Object -First 1
        if (-not $runtimeSource) { throw 'The WebView2 runtime package layout was not recognized.' }
        $runtimeDestination = Join-Path $InstallRoot 'WebView2FixedRuntime'
        Remove-Item $runtimeDestination -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item $runtimeSource.FullName $runtimeDestination -Recurse -Force

        New-Item -ItemType Directory -Force -Path $StartMenuFolder | Out-Null
        New-Shortcut $DesktopShortcut
        New-Shortcut (Join-Path $StartMenuFolder 'C Browser.lnk')
        New-Item -Path $UninstallKey -Force | Out-Null
        New-ItemProperty $UninstallKey DisplayName $AppName -PropertyType String -Force | Out-Null
        New-ItemProperty $UninstallKey DisplayVersion $Version -PropertyType String -Force | Out-Null
        New-ItemProperty $UninstallKey Publisher 'perth3132' -PropertyType String -Force | Out-Null
        New-ItemProperty $UninstallKey InstallLocation $InstallRoot -PropertyType String -Force | Out-Null
        New-ItemProperty $UninstallKey DisplayIcon (Join-Path $InstallRoot 'browser.exe') -PropertyType String -Force | Out-Null
        $installedSetup = Join-Path $InstallRoot 'C-Browser-Setup.ps1'
        $uninstallCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installedSetup`" -Uninstall"
        New-ItemProperty $UninstallKey UninstallString $uninstallCommand -PropertyType String -Force | Out-Null
        Write-Host "$AppName installed to $InstallRoot"
        Write-Host 'A desktop and Start Menu shortcut were created.'
    } finally {
        Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Uninstall) { Remove-InstalledBrowser } else { Install-Browser }
