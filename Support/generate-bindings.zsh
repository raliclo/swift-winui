#!/usr/bin/env zsh
# generate-bindings.zsh -- regenerate swift-winui's Swift/WinRT bindings and the
# CWinAppSDK NuGet files from the versions pinned in Support/*/projections.json.
# 依 Support/*/projections.json 固定的版本，重新產生 swift-winui 的 Swift/WinRT
# bindings 與 CWinAppSDK 的 NuGet 檔案。
#
#   zsh Support/generate-bindings.zsh                  # fetch, generate, assets
#   zsh Support/generate-bindings.zsh fetch            # download packages only / 只下載套件
#   zsh Support/generate-bindings.zsh generate [M...]  # run swiftwinrt (M = WinUI, UWP, ...)
#   zsh Support/generate-bindings.zsh assets           # refresh Sources/CWinAppSDK/nuget
#   zsh Support/generate-bindings.zsh --help
#
# Modules / 模組: WindowsFoundation UWP WinAppSDK WebView2Core WinUI CWinRT
# Packages land in Support/.packages (gitignored). / 套件放在 Support/.packages（已 gitignore）。
#
# Why this replaces the six generate-bindings.ps1 (2026-11-05) / 為何取代那六支 ps1：
# - Script logic lives in zsh on Windows (the user's rule). / Windows 上的腳本邏輯一律寫 zsh（使用者規則）。
# - The ps1 called `Get-WinMDInputs -Package $Package` with $Package never set, so
#   every .winmd under .packages became an input. Here the inputs are exactly the
#   module's own packages. / ps1 傳入從未設定的 $Package，於是 .packages 底下所有
#   .winmd 都成了輸入；這裡的輸入恰好是該模組自己列出的套件。
# - Windows App SDK 2.x is a metapackage with no .winmd of its own, so each
#   projections.json names the component packages (Foundation, InteractiveExperiences,
#   WinUI, Runtime). / 2.x 是不含 .winmd 的 metapackage，所以 projections.json 直接列出元件套件。
# - InteractiveExperiences ships the same .winmd under 10.0.17763.0 and 10.0.18362.0;
#   passing both to swiftwinrt duplicates every type. One file per name is kept, the
#   highest folder wins. / 同名 .winmd 出現在兩個版本資料夾，兩個都傳會讓型別重複；
#   每個檔名只留一份，取版本最高的資料夾。

set -u
setopt pipe_fail

script_path="${0:A}"
support_dir="${script_path:h}"
repo_dir="${support_dir:h}"
packages_dir="$support_dir/.packages"
all_modules=(WindowsFoundation UWP WinAppSDK WebView2Core WinUI CWinRT)

if [[ "${1:-}" == (-h|--help) ]]; then
    sed -n '2,13p' "$script_path" | sed 's/^# \{0,1\}//'
    exit 0
fi

stage="${1:-all}"
(( $# )) && shift
case "$stage" in
    all|fetch|generate|assets) ;;
    *) printf 'unknown stage: %s (try --help)\n' "$stage" >&2; exit 2 ;;
esac

# The packages one module lists, as "id version" lines.
# 一個模組列出的套件，每行「id version」。
module_packages() {
    jq -r '[.package?, (.packages // [])[], (.dependencies // [])[]]
           | map(select(. != null)) | .[] | "\(.id) \(.version)"' \
        "$support_dir/$1/projections.json" | tr -d '\r'
}

swiftwinrt_version() {
    jq -r '."swift-winrt"' "$support_dir/$1/projections.json" | tr -d '\r'
}

# NuGet folders are lowercase ids, as the flat container serves them.
# NuGet 資料夾用小寫 id，與 flat container 一致。
package_dir() {
    printf '%s/%s.%s' "$packages_dir" "${1:l}" "$2"
}

fetch_package() {
    local id="$1" version="$2" dir nupkg
    dir="$(package_dir "$id" "$version")"
    [[ -d "$dir" ]] && return 0
    nupkg="$dir.nupkg"
    mkdir -p "$packages_dir"
    printf '  fetch %s %s\n' "$id" "$version"
    if ! curl -sfL -o "$nupkg" \
        "https://api.nuget.org/v3-flatcontainer/${id:l}/$version/${id:l}.$version.nupkg"; then
        printf 'download failed: %s %s\n' "$id" "$version" >&2
        return 1
    fi
    mkdir -p "$dir" && unzip -q -o "$nupkg" -d "$dir" && rm -f "$nupkg"
}

fetch_all() {
    local m line
    for m in $all_modules; do
        fetch_package TheBrowserCompany.SwiftWinRT "$(swiftwinrt_version "$m")" || return 1
        for line in ${(f)"$(module_packages "$m")"}; do
            fetch_package ${=line} || return 1
        done
    done
}

# One .winmd per file name across a module's packages; the highest folder wins.
# 一個模組的所有套件中，每個 .winmd 檔名只留一份，取最高版本的資料夾。
module_winmds() {
    local line dir f
    typeset -A pick
    for line in ${(f)"$(module_packages "$1")"}; do
        dir="$(package_dir ${=line})"
        for f in ${(f)"$(find "$dir" -name '*.winmd' | sort -V)"}; do
            [[ -n "$f" ]] && pick[${f:t}]="$f"
        done
    done
    printf '%s\n' "${(@v)pick}"
}

generate_module() {
    local m="$1" json="$support_dir/$1/projections.json"
    local out="$support_dir/$1/.generated" rsp="$support_dir/$1/swift-winrt.rsp"
    local swiftwinrt p dest f
    swiftwinrt="$(package_dir TheBrowserCompany.SwiftWinRT "$(swiftwinrt_version "$m")")/bin/swiftwinrt.exe"
    [[ -x "$swiftwinrt" ]] || { printf 'missing %s; run the fetch stage\n' "$swiftwinrt" >&2; return 1; }

    [[ "$out" == */Support/$m/.generated ]] && rm -rf "$out"
    {
        printf -- '-output "%s"\n' "$(cygpath -w "$out")"
        jq -r '(.include // [])[]' "$json" | tr -d '\r' | while read -r f; do printf -- '-include "%s"\n' "$f"; done
        jq -r '(.exclude // [])[]' "$json" | tr -d '\r' | while read -r f; do printf -- '-exclude "%s"\n' "$f"; done
        module_winmds "$m" | while read -r f; do printf -- '-input "%s"\n' "$(cygpath -w "$f")"; done
    } > "$rsp"

    printf '==> %s: swiftwinrt %s inputs\n' "$m" "$(grep -c '^-input' "$rsp")"
    if ! "$swiftwinrt" "@$(cygpath -w "$rsp")"; then
        printf 'swiftwinrt failed for %s\n' "$m" >&2
        return 1
    fi

    # CWinRT is copied whole; every other project into its Generated folder.
    # CWinRT 整個複製；其他專案複製到各自的 Generated 資料夾。
    for p in ${(f)"$(jq -r '[.project?, (.projects // [])[]] | map(select(. != null)) | .[]' "$json" | tr -d '\r')"}; do
        if [[ "$p" == CWinRT ]]; then dest="$repo_dir/Sources/CWinRT"; else dest="$repo_dir/Sources/$p/Generated"; fi
        [[ -d "$out/Sources/$p" ]] || { printf 'swiftwinrt produced no Sources/%s\n' "$p" >&2; return 1; }
        [[ "$dest" == "$repo_dir"/Sources/* ]] && rm -rf "$dest"
        mkdir -p "$dest" && cp -R "$out/Sources/$p/." "$dest/"
        printf '    %s -> %s (%s files)\n' "$p" "${dest#$repo_dir/}" "$(find "$dest" -type f | wc -l | tr -d ' ')"
    done
}

# Refresh every file already in Sources/CWinAppSDK/nuget from the pinned packages,
# matched by name and architecture; files with no match are listed, not dropped.
# 以檔名與架構，從固定版本的套件更新 Sources/CWinAppSDK/nuget 中既有的每個檔案；
# 找不到的列出來，不刪除。
refresh_assets() {
    local nuget="$repo_dir/Sources/CWinAppSDK/nuget" line f rel arch hit
    local -a dirs candidates missing
    local updated=0
    for line in ${(f)"$(module_packages WinAppSDK; module_packages WebView2Core; module_packages CWinRT)"}; do
        dirs+=("$(package_dir ${=line})")
    done
    dirs=(${(u)dirs})
    for f in ${(f)"$(find "$nuget" -type f | sort)"} ${(f)"$(ls "$repo_dir"/Microsoft.WindowsAppRuntime.Bootstrap.dll 2>/dev/null)"}; do
        rel="${f#$repo_dir/}"
        case "$rel" in
            */bin/arm64/*) arch=arm64 ;;
            */include/*) arch='' ;;
            *) arch=x64 ;;
        esac
        candidates=(${(f)"$(find $dirs -type f -iname "${f:t}" 2>/dev/null)"})
        if [[ -n "$arch" ]]; then
            candidates=(${(M)candidates:#*[/-]${arch}/*})
        else
            candidates=(${(M)candidates:#*/include/*})
        fi
        hit="${candidates[1]:-}"
        if [[ -z "$hit" ]]; then missing+=("$rel"); continue; fi
        cmp -s "$hit" "$f" || { cp "$hit" "$f"; updated=$((updated + 1)); printf '    %s <- %s\n' "$rel" "${hit#$packages_dir/}"; }
    done
    printf '==> assets: %d updated, %d not found in the packages\n' "$updated" "${#missing}"
    (( ${#missing} )) && printf '    missing: %s\n' "${missing[@]}"
    return 0
}

case "$stage" in
    fetch) fetch_all ;;
    generate)
        selected_modules=("$@"); (( ${#selected_modules} )) || selected_modules=($all_modules)
        for m in $selected_modules; do generate_module "$m" || exit 1; done ;;
    assets) refresh_assets ;;
    all)
        fetch_all || exit 1
        for m in $all_modules; do generate_module "$m" || exit 1; done
        refresh_assets ;;
esac
