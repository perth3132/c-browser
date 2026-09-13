[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CWebBrowser'),
    [string]$FixedRuntimeVersion = '152.0.4191.62'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimePackage = Join-Path $env:TEMP "WebView2.Runtime.X64.$FixedRuntimeVersion.nupkg"
$runtimeArchive = Join-Path $env:TEMP "WebView2.Runtime.X64.$FixedRuntimeVersion.zip"
$runtimeUrl = "https://www.nuget.org/api/v2/package/WebView2.Runtime.X64/$FixedRuntimeVersion"
$runtimeTemp = Join-Path $env:TEMP "CWebBrowser-WebView2-$FixedRuntimeVersion"
$uninstallerPath = Join-Path $InstallRoot 'uninstall.ps1'
$startMenuPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'C Browser'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CWebBrowser'

if (-not (Test-Path (Join-Path $projectRoot 'browser.exe'))) {
    throw 'browser.exe is missing. Build the project before running the installer.'
}
if (-not (Test-Path (Join-Path $projectRoot 'WebView2Loader.dll'))) {
    throw 'WebView2Loader.dll is missing. Build the project before running the installer.'
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Copy-Item (Join-Path $projectRoot 'browser.exe') $InstallRoot -Force
Copy-Item (Join-Path $projectRoot 'WebView2Loader.dll') $InstallRoot -Force
Copy-Item (Join-Path $projectRoot 'uninstall.ps1') $uninstallerPath -Force

if (Test-Path $runtimeTemp) { Remove-Item $runtimeTemp -Recurse -Force }
if (-not (Test-Path $runtimePackage)) {
    Invoke-WebRequest -Uri $runtimeUrl -OutFile $runtimePackage
}
Copy-Item $runtimePackage $runtimeArchive -Force
Expand-Archive -Path $runtimeArchive -DestinationPath $runtimeTemp -Force
$runtimeSource = Get-ChildItem $runtimeTemp -Directory -Recurse |
    Where-Object { $_.Name -eq 'WebView2' } |
    Select-Object -First 1
if (-not $runtimeSource) { throw 'The fixed WebView2 runtime package layout was not recognized.' }

$runtimeDestination = Join-Path $InstallRoot 'WebView2FixedRuntime'
if (Test-Path $runtimeDestination) { Remove-Item $runtimeDestination -Recurse -Force }
Copy-Item $runtimeSource.FullName $runtimeDestination -Recurse -Force

$shell = New-Object -ComObject WScript.Shell
$shortcutTargets = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'C Browser.lnk'),
    (Join-Path $startMenuPath 'C Browser.lnk')
)
New-Item -ItemType Directory -Force -Path $startMenuPath | Out-Null
foreach ($shortcutPath in $shortcutTargets) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $InstallRoot 'browser.exe'
    $shortcut.WorkingDirectory = $InstallRoot
    $shortcut.Description = 'C Browser'
    $shortcut.Save()
}

New-Item -Path $uninstallKey -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name DisplayName -Value 'C Browser' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name DisplayVersion -Value '1.0.0' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name Publisher -Value 'perth3132' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name DisplayIcon -Value (Join-Path $InstallRoot 'browser.exe') -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name UninstallString -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstallerPath`"" -PropertyType String -Force | Out-Null

Write-Host "Installed C Browser to $InstallRoot"
Write-Host "Fixed WebView2 runtime: $FixedRuntimeVersion"
Write-Host "UserDataFolder: $env:LOCALAPPDATA\CWebBrowser\UserData"
