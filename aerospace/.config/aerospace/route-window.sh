#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=C
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

workspace_for_app() {
    local app_name=${1-}
    local initial=${app_name:0:1}

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

if [[ ${1-} == '--print-workspace' ]]; then
    if [[ $# -ne 3 ]]; then
        printf 'Usage: %s --print-workspace APP_NAME APP_BUNDLE_PATH\n' "$0" >&2
        exit 64
    fi

    is_applications_bundle "$3" || exit 1
    workspace_for_app "$2"
    exit
fi

if [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--print-workspace APP_NAME APP_BUNDLE_PATH]\n' "$0" >&2
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

if ! workspace=$(workspace_for_app "$app_name"); then
    exit 0
fi

aerospace move-node-to-workspace --window-id "$window_id" -- "$workspace"
