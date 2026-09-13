# C Web Browser

This is a small Windows desktop browser written in C. It embeds Microsoft Edge WebView2, so modern sites can render HTML, CSS, JavaScript, images, audio, video, cookies, and forms.

The installer includes a fixed WebView2 runtime under `WebView2FixedRuntime`. Its writable WebView2 `UserDataFolder` is explicitly set to `%LOCALAPPDATA%\CWebBrowser\UserData`, so installation does not require writing to `Program Files`. The default build uses the installed system WebView2 runtime because the fixed runtime crashes with the loader available on this machine; set `CBROWSER_USE_FIXED_RUNTIME=1` only when testing the fixed runtime.

The browser creates one WebView2 environment/controller and reuses it while the window is visible. When minimized or closed, it calls the native equivalent of `Dispose()` (`Close()` plus COM `Release()`) to release browser memory. Restoring the minimized window creates a fresh instance.

## Build with LLVM Clang

From this folder, run:

```powershell
clang browser.c -I vendor\webview2\build\native\include `
	vendor\webview2\build\native\x64\WebView2Loader.dll.lib `
	-o browser.exe -mwindows -lole32 -luser32 -lgdi32
Copy-Item vendor\webview2\build\native\x64\WebView2Loader.dll . -Force
```

## Install fixed runtime

After building, install the browser and fixed WebView2 runtime with:

```powershell
.\install.ps1
```

The installer downloads the pinned `WebView2.Runtime.X64` version `152.0.4191.62`, matched to the WebView2 loader used by this build, installs it beside the browser, and creates a desktop shortcut. The installer is per-user and writes to `%LOCALAPPDATA%\CWebBrowser`.

It also creates a Start Menu shortcut and registers C Browser under Windows Apps and Features. To uninstall from PowerShell:

```powershell
.\uninstall.ps1
```

By default uninstallation removes the browser, fixed runtime, shortcuts, registry entry, and `%LOCALAPPDATA%\CWebBrowser\UserData`. Keep the user data with:

```powershell
.\uninstall.ps1 -KeepUserData
```

Then run:

```powershell
.\browser.exe
```