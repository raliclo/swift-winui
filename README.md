# swift-winui

Swift Language Bindings for common WinRT APIs and the Windows App SDK. For now, this package hosts bindings for WinUI 3, the Windows App SDK, UWP, Windows Foundation, and WebView 2 Core.

## Bindings

The bindings are generated using [thebrowsercompany/swift-winrt](https://github.com/thebrowsercompany/swift-winrt). To discover which bindings each product provides bindings for, see the `projections.json` file in the corresponding subdirectory of the `Support` directory.

## Useful resources

- [Windows App SDK API documentation](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.controls?view=windows-app-sdk-1.5)
- [Official WinUI 3 GitHub repo](https://github.com/microsoft/microsoft-ui-xaml)

## SDK Versions

These bindings target a specific Windows SDK and a specific Windows App SDK. Bindings for the Windows SDK are compatible with all Windows SDK versions that follow. Bindings for Windows App SDK APIs on the other hand require that a matching Windows App Runtime version is installed.

1. Windows SDK: `10.0.17763.0` (until 2026-11-06; now the `Microsoft.Windows.SDK.Contracts` `10.0.26100.9457` metadata / 至 2026-11-06 為止；現為 `Microsoft.Windows.SDK.Contracts` `10.0.26100.9457` 的 metadata)
2. Windows App SDK: `1.5-preview1` (until 2026-11-06; now `2.6.5`, generated with swift-winrt `0.6.0` / 至 2026-11-06 為止；現為 `2.6.5`，以 swift-winrt `0.6.0` 產生)

## Depenencies

### Compiletime dependencies

To compile an app that uses swift-winui, you must install a matching version of the Windows SDK;

```pwsh
winget install --id Microsoft.WindowsSDK.10.0.17763
```

### Runtime dependencies

To run an app that uses swift-winui, you must install the correct version of the Windows App Runtime;

- x64: [windowsappruntimeinstall-x64.exe](https://aka.ms/windowsappsdk/1.5/1.5.240205001-preview1/windowsappruntimeinstall-x64.exe)
- arm64: [windowsappruntimeinstall-arm64.exe](https://aka.ms/windowsappsdk/1.5/1.5.240205001-preview1/windowsappruntimeinstall-arm64.exe)

Superseded 2026-11-06: the links above are for 1.5-preview1, which these bindings no longer match. They now need the Windows App Runtime 2.6 (`Microsoft.WindowsAppRuntime.2`, built against 2.6.5); get it from the [Windows App SDK downloads page](https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads). An app built against these bindings but loading an older bootstrap DLL reports that it requires Windows App Runtime Version 2.6.
已於 2026-11-06 取代：上面的連結是 1.5-preview1 的，這些 bindings 已不再對應它。現在需要 Windows App Runtime 2.6（`Microsoft.WindowsAppRuntime.2`，以 2.6.5 建置），請從上面的 Windows App SDK 下載頁取得。用這些 bindings 建置、卻載入舊版 bootstrap DLL 的 app，會回報需要 Windows App Runtime Version 2.6。

## Regenerating the bindings

`zsh Support/generate-bindings.zsh` downloads the packages pinned in `Support/*/projections.json`, runs swift-winrt, and refreshes `Sources/CWinAppSDK/nuget`. Run it with `--help` for the stages. It replaces the six `Support/*/generate-bindings.ps1`, which passed an unset `$Package` and so fed every downloaded .winmd to every module.
`zsh Support/generate-bindings.zsh` 會下載 `Support/*/projections.json` 固定的套件、執行 swift-winrt，並更新 `Sources/CWinAppSDK/nuget`；各階段見 `--help`。它取代六支 `Support/*/generate-bindings.ps1`，那些腳本傳入未設定的 `$Package`，於是每個模組都吃進所有下載的 .winmd。
