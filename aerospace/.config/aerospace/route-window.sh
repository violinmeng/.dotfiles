#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=C
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

workspace_for_app() {
    local app_name=${1-}
    local app_bundle_id=${2-}
    local initial

    case "$app_bundle_id" in
        com.electron.lark) printf '1\n'; return ;;
        com.todesktop.230313mzl4w4u92) printf 'U\n'; return ;;
    esac

    initial=${app_name:0:1}
    initial=$(printf '%s' "$initial" | tr '[:lower:]' '[:upper:]')
    case "$initial" in
        [A-Z]) printf '%s\n' "$initial" ;;
        *) return 1 ;;
    esac
}

is_applications_bundle() {
    local bundle_path=${1%/}
    local relative_path

    case "$bundle_path" in
        /Applications/*.app)
            relative_path=${bundle_path#/Applications/}
            [[ $relative_path != *'.app/'* ]]
            ;;
        *) return 1 ;;
    esac
}

is_first_app_window() {
    local current_window_id=$1
    local app_bundle_id=$2
    local app_window_ids
    local candidate_window_id

    if ! app_window_ids=$(aerospace list-windows --monitor all \
        --app-bundle-id "$app_bundle_id" --format '%{window-id}'); then
        return 1
    fi

    while IFS= read -r candidate_window_id; do
        [[ -z $candidate_window_id || $candidate_window_id == "$current_window_id" ]] && continue
        return 1
    done <<< "$app_window_ids"

    return 0
}

monitor_width_for_window() {
    local window_id=$1
    local monitor_name

    monitor_name=$(aerospace echo --window-id "$window_id" -- '%{monitor-name}') || return 1
    [[ -n $monitor_name ]] || return 1

    osascript -l JavaScript - "$monitor_name" <<'JXA'
ObjC.import('AppKit')

function run(argv) {
    const targetMonitor = argv[0]
    for (const screen of $.NSScreen.screens.js) {
        if (ObjC.unwrap(screen.localizedName) === targetMonitor) {
            return String(Math.round(screen.visibleFrame.size.width))
        }
    }
    return ''
}
JXA
}

resize_window_for_app() {
    local window_id=$1
    local app_bundle_id=$2
    local monitor_width
    local workspace
    local app_window_count
    local width_divisor

    case "$app_bundle_id" in
        com.vphone.cli)
            monitor_width=$(monitor_width_for_window "$window_id") || return 0
            workspace=$(aerospace echo --window-id "$window_id" -- '%{workspace}') || return 0
            app_window_count=$(aerospace list-windows --workspace "$workspace" \
                --app-bundle-id "$app_bundle_id" --count) || return 0
            [[ $monitor_width =~ ^[0-9]+$ && $app_window_count =~ ^[1-9][0-9]*$ ]] || return 0
            width_divisor=$((4 * app_window_count))
            aerospace layout --window-id "$window_id" tiling
            aerospace resize --window-id "$window_id" width "$((monitor_width / width_divisor))"
            ;;
    esac
}

resize_vphone_windows() {
    local scope_flag=$1
    local scope_value=$2
    local window_id

    while IFS= read -r window_id; do
        [[ -n $window_id ]] || continue
        resize_window_for_app "$window_id" com.vphone.cli
    done < <(aerospace list-windows "$scope_flag" "$scope_value" \
        --app-bundle-id com.vphone.cli --format '%{window-id}')
}

resize_vphone_windows_in_focused_workspace() {
    local workspace

    workspace=$(aerospace list-workspaces --focused --format '%{workspace}') || return 0
    [[ -n $workspace ]] || return 0
    resize_vphone_windows --workspace "$workspace"
}

if [[ ${1-} == '--print-workspace' ]]; then
    if [[ $# -ne 4 ]]; then
        printf 'Usage: %s --print-workspace APP_NAME APP_BUNDLE_ID APP_BUNDLE_PATH\n' "$0" >&2
        exit 64
    fi

    is_applications_bundle "$4" || exit 1
    workspace_for_app "$2" "$3"
    exit
fi

if [[ ${1-} == '--resize-vphone-windows' ]]; then
    [[ $# -eq 1 ]] || exit 64
    command -v aerospace >/dev/null 2>&1 || exit 0
    resize_vphone_windows --monitor all
    exit
fi

if [[ ${1-} == '--resize-vphone-windows-in-focused-workspace' ]]; then
    [[ $# -eq 1 ]] || exit 64
    command -v aerospace >/dev/null 2>&1 || exit 0
    resize_vphone_windows_in_focused_workspace
    exit
fi

if [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--print-workspace APP_NAME APP_BUNDLE_ID APP_BUNDLE_PATH | --resize-vphone-windows | --resize-vphone-windows-in-focused-workspace]\n' "$0" >&2
    exit 64
fi

window_id=${AEROSPACE_WINDOW_ID-}
[[ -n $window_id ]] || exit 0
command -v aerospace >/dev/null 2>&1 || exit 0

if ! app_bundle_path=$(aerospace echo --window-id "$window_id" -- '%{app-bundle-path}'); then
    exit 0
fi
is_applications_bundle "$app_bundle_path" || exit 0

if ! app_bundle_id=$(aerospace echo --window-id "$window_id" -- '%{app-bundle-id}'); then
    exit 0
fi
[[ -n $app_bundle_id ]] || exit 0
is_first_app_window "$window_id" "$app_bundle_id" || exit 0

if ! app_name=$(aerospace echo --window-id "$window_id" -- '%{app-name}'); then
    exit 0
fi

if ! workspace=$(workspace_for_app "$app_name" "$app_bundle_id"); then
    exit 0
fi

aerospace move-node-to-workspace --focus-follows-window \
    --window-id "$window_id" -- "$workspace"
if [[ $app_bundle_id == com.vphone.cli ]]; then
    resize_vphone_windows --workspace "$workspace"
else
    resize_window_for_app "$window_id" "$app_bundle_id"
fi
