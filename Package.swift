// swift-tools-version: 5.10

import PackageDescription

// Microsoft.Web.WebView2.Core.dll (WebView2 SDK 1.0.4314.35, native_uap) ships with
// the resources because the Windows App SDK 2.x framework package no longer carries
// it; 1.5's did. Without it WinUI's WebView2 never starts its core: no error, no
// browser process, and EnsureCoreWebView2Async never completes (P38, 2026-11-06).
// It works beside the executable (other places not tried), so the app's build copies it out of the bundle.
// Microsoft.Web.WebView2.Core.dll(WebView2 SDK 1.0.4314.35,native_uap)隨資源一起提供，因為 Windows App SDK 2.x
// 的 framework 套件不再附帶它，1.5 的有。少了它,WinUI 的 WebView2 永遠不會啟動核心：沒有錯誤、沒有瀏覽器行程,
// EnsureCoreWebView2Async 也永不完成(P38,2026-11-06)。放在執行檔旁邊可行(其他位置未試),所以由 app 的建置把它從 bundle 複製出來。
#if arch(x86_64)
    let windowsAppRTBootstrapDll: Resource = .copy("nuget/bin/x86_64/Microsoft.WindowsAppRuntime.Bootstrap.dll")
    let webView2CoreDll: Resource = .copy("nuget/bin/x86_64/Microsoft.Web.WebView2.Core.dll")
#elseif arch(arm64)
    let windowsAppRTBootstrapDll: Resource = .copy("nuget/bin/arm64/Microsoft.WindowsAppRuntime.Bootstrap.dll")
    let webView2CoreDll: Resource = .copy("nuget/bin/arm64/Microsoft.Web.WebView2.Core.dll")
#endif

let package = Package(
    name: "swift-winui",
    products: [
        .library(name: "WinUI", type: .static, targets: ["WinUI"]),
        .library(name: "WebView2Core", type: .static, targets: ["WebView2Core"]),
        .library(name: "WinAppSDK", type: .static, targets: ["WinAppSDK"]),
        .library(name: "UWP", type: .static, targets: ["UWP"]),
        .library(name: "WindowsFoundation", type: .static, targets: ["WindowsFoundation"]),
        .library(name: "CWinRT", type: .static, targets: ["CWinRT"]),
    ],
    targets: [
        .target(
            name: "WinUI",
            dependencies: [
                "CWinRT",
                "UWP",
                "WinAppSDK",
                "WindowsFoundation",
                "WebView2Core",
            ]
        ),
        .target(name: "CWinRT"),
        .target(
            name: "UWP",
            dependencies: [
                "CWinRT",
                "WindowsFoundation",
            ]
        ),
        .target(
            name: "WinAppSDK",
            dependencies: [
                "CWinRT",
                "UWP",
                "WindowsFoundation",
                "CWinAppSDK",
            ]
        ),
        .target(
            name: "CWinAppSDK",
            resources: [
                windowsAppRTBootstrapDll,
                webView2CoreDll,
            ]
        ),
        .target(
            name: "WindowsFoundation",
            dependencies: [
                "CWinRT",
            ]
        ),
        .target(
            name: "WebView2Core",
            dependencies: [
                "CWinRT",
                "UWP",
                "WindowsFoundation",
            ]
        ),
    ]
)
