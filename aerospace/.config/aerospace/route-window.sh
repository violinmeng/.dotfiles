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

if [[ ${1-} == '--print-workspace' ]]; then
    if [[ $# -ne 2 ]]; then
        printf 'Usage: %s --print-workspace APP_NAME\n' "$0" >&2
        exit 64
    fi

    workspace_for_app "$2"
    exit
fi

if [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--print-workspace APP_NAME]\n' "$0" >&2
    exit 64
fi

window_id=${AEROSPACE_WINDOW_ID-}
[[ -n $window_id ]] || exit 0
command -v aerospace >/dev/null 2>&1 || exit 0

if ! app_name=$(aerospace echo --window-id "$window_id" -- '%{app-name}'); then
    exit 0
fi

if ! workspace=$(workspace_for_app "$app_name"); then
    exit 0
fi

aerospace move-node-to-workspace --window-id "$window_id" -- "$workspace"
