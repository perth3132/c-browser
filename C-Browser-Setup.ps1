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
$RuntimeVersion = '152.0.4191.62'
$Repo = 'https://raw.githubusercontent.com/perth3132/c-browser/main'
$RuntimeUrl = "https://www.nuget.org/api/v2/package/WebView2.Runtime.X64/$RuntimeVersion"
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CWebBrowser'
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'C Browser.lnk'
$StartMenuFolder = Join-Path ([Environment]::GetFolderPath('Programs')) 'C Browser'
$UserData = Join-Path $env:LOCALAPPDATA 'CWebBrowser\UserData'

if ($Uninstall -and -not $Cleanup) {
    $temporaryUninstaller = Join-Path $env:TEMP "C-Browser-Uninstall-$([Guid]::NewGuid().ToString('N')).ps1"
    Copy-Item $PSCommandPath $temporaryUninstaller -Force
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $temporaryUninstaller,
        '-Uninstall', '-Cleanup', '-InstallRoot', $InstallRoot)
    if ($KeepUserData) { $arguments += '-KeepUserData' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden
    Write-Host "$AppName uninstall started."
    exit 0
}

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
    if ($KeepUserData) {
        Get-ChildItem $InstallRoot -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $UserData } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Remove-Item $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $cleanupCommand = "timeout /t 2 /nobreak >nul & del /q `"$PSCommandPath`""
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cleanupCommand -WindowStyle Hidden
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
        $installedSetup = Join-Path $InstallRoot 'C-Browser-Setup.ps1'
        if ([IO.Path]::GetFullPath($PSCommandPath) -ne [IO.Path]::GetFullPath($installedSetup)) {
            Copy-Item $PSCommandPath $installedSetup -Force
        }
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
        New-ItemProperty -Path $UninstallKey -Name DisplayName -Value $AppName -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $UninstallKey -Name DisplayVersion -Value $Version -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $UninstallKey -Name Publisher -Value 'perth3132' -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $UninstallKey -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $UninstallKey -Name DisplayIcon -Value (Join-Path $InstallRoot 'browser.exe') -PropertyType String -Force | Out-Null
        $uninstallCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installedSetup`" -Uninstall"
        New-ItemProperty -Path $UninstallKey -Name UninstallString -Value $uninstallCommand -PropertyType String -Force | Out-Null
        Write-Host "$AppName installed to $InstallRoot"
        Write-Host 'A desktop and Start Menu shortcut were created.'
    } finally {
        Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Uninstall) { Remove-InstalledBrowser } else { Install-Browser }
