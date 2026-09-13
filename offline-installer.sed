[Version]
Class=IEXPRESS
SEDVersion=3

[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=1
CABFILENAME=C-Browser-Offline.cab
TargetName=D:\AICoding\website\C-Browser-Offline-Installer.exe
FriendlyName=C Browser Offline Installer
AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -File offline-setup.ps1
PostInstallCommand=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles

[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=C Browser was installed. A desktop shortcut is available.

[SourceFiles]
SourceFiles0=D:\AICoding\website\offline-payload\

[SourceFiles0]
browser.exe=
WebView2Loader.dll=
offline-setup.ps1=
offline-payload.zip=
