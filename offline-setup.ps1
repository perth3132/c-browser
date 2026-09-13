[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$KeepUserData,
    [switch]$Cleanup,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CWebBrowser')
)

$ErrorActionPreference = 'Stop'
$AppName = 'C Browser'
$Version = '1.0.0'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CWebBrowser'
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'C Browser.lnk'
$StartMenuFolder = Join-Path ([Environment]::GetFolderPath('Programs')) 'C Browser'
$UserData = Join-Path $env:LOCALAPPDATA 'CWebBrowser\UserData'

if ($Uninstall -and -not $Cleanup) {
    $temporary = Join-Path $env:TEMP "C-Browser-Offline-Uninstall-$([Guid]::NewGuid().ToString('N')).ps1"
    Copy-Item $PSCommandPath $temporary -Force
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $temporary,
        '-Uninstall', '-Cleanup', '-InstallRoot', $InstallRoot)
    if ($KeepUserData) { $arguments += '-KeepUserData' }
    Start-Process powershell.exe -ArgumentList $arguments -WindowStyle Hidden
    Write-Host "$AppName offline uninstall started."
    exit 0
}

function New-Shortcut([string]$Path) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = Join-Path $InstallRoot 'browser.exe'
    $shortcut.WorkingDirectory = $InstallRoot
    $shortcut.Description = $AppName
    $shortcut.Save()
}

function Uninstall-Browser {
    Get-Process -Name browser -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq (Join-Path $InstallRoot 'browser.exe') } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item $DesktopShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item $StartMenuFolder -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $UninstallKey -Recurse -Force -ErrorAction SilentlyContinue
    if ($KeepUserData) {
        Get-ChildItem $InstallRoot -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $UserData } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Remove-Item $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue
    Write-Host "$AppName was uninstalled."
}

function Install-Browser {
    $packageRoot = Split-Path -Parent $PSCommandPath
    $payloadRoot = $packageRoot
    $temporaryPayload = Join-Path $env:TEMP "C-Browser-Offline-Payload-$([Guid]::NewGuid().ToString('N'))"
    if (Test-Path (Join-Path $packageRoot 'offline-payload.zip')) {
        Expand-Archive (Join-Path $packageRoot 'offline-payload.zip') -DestinationPath $temporaryPayload -Force
        $payloadRoot = $temporaryPayload
    }
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    Copy-Item (Join-Path $payloadRoot 'browser.exe') $InstallRoot -Force
    Copy-Item (Join-Path $payloadRoot 'WebView2Loader.dll') $InstallRoot -Force
    Copy-Item (Join-Path $payloadRoot 'WebView2FixedRuntime') (Join-Path $InstallRoot 'WebView2FixedRuntime') -Recurse -Force
    Copy-Item $PSCommandPath (Join-Path $InstallRoot 'C-Browser-Offline-Setup.ps1') -Force
    $startMenu = Join-Path $StartMenuFolder 'C Browser.lnk'
    New-Item -ItemType Directory -Force -Path $StartMenuFolder | Out-Null
    New-Shortcut $DesktopShortcut
    New-Shortcut $startMenu
    New-Item -Path $UninstallKey -Force | Out-Null
    New-ItemProperty -Path $UninstallKey -Name DisplayName -Value $AppName -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallKey -Name DisplayVersion -Value $Version -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallKey -Name Publisher -Value 'perth3132' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallKey -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallKey -Name DisplayIcon -Value (Join-Path $InstallRoot 'browser.exe') -PropertyType String -Force | Out-Null
    $uninstaller = Join-Path $InstallRoot 'C-Browser-Offline-Setup.ps1'
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstaller`" -Uninstall"
    New-ItemProperty -Path $UninstallKey -Name UninstallString -Value $command -PropertyType String -Force | Out-Null
    Remove-Item $temporaryPayload -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "$AppName installed offline to $InstallRoot"
}

if ($Uninstall) { Uninstall-Browser } else { Install-Browser }
