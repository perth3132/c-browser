[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CWebBrowser'),
    [switch]$KeepUserData
)

$ErrorActionPreference = 'Stop'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CWebBrowser'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'C Browser.lnk'
$startMenuFolder = Join-Path ([Environment]::GetFolderPath('Programs')) 'C Browser'
$userData = Join-Path $env:LOCALAPPDATA 'CWebBrowser\UserData'

Get-Process -Name browser -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq (Join-Path $InstallRoot 'browser.exe') } |
    Stop-Process -Force -ErrorAction SilentlyContinue

Remove-Item $desktopShortcut -Force -ErrorAction SilentlyContinue
Remove-Item $startMenuFolder -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue

if (-not $KeepUserData) {
    Remove-Item $userData -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path $InstallRoot) {
    Remove-Item $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'C Browser was uninstalled.'
if ($KeepUserData) {
    Write-Host "User data was kept at $userData"
}