#!/bin/bash

set -Eeuo pipefail

if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
    printf 'Error: HOME is not set to an existing directory.\n' >&2
    exit 1
fi

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SCRIPT_SOURCE" ]]; do
    SCRIPT_DIRECTORY="$(cd -P -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd)"
    LINK_TARGET="$(readlink "$SCRIPT_SOURCE")"
    if [[ "$LINK_TARGET" == /* ]]; then
        SCRIPT_SOURCE="$LINK_TARGET"
    else
        SCRIPT_SOURCE="$SCRIPT_DIRECTORY/$LINK_TARGET"
    fi
done

readonly SCRIPT_NAME="${0##*/}"
readonly REPO_ROOT="$(cd -P -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd)"
readonly LOGIN_PROFILE_FILE="${LOGIN_PROFILE_FILE:-${PROFILE_FILE:-$HOME/.zprofile}}"
readonly BREWFILE="$REPO_ROOT/Brewfile"
readonly MISE_CONFIG_SOURCE="$REPO_ROOT/mise.toml"
readonly MISE_CONFIG_TARGET="$HOME/.config/mise/config.toml"

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.zsh-custom}"
OH_MY_ZSH_REPO="${OH_MY_ZSH_REPO:-ohmyzsh/ohmyzsh}"
OH_MY_ZSH_REMOTE="${OH_MY_ZSH_REMOTE:-https://github.com/${OH_MY_ZSH_REPO}.git}"
OH_MY_ZSH_BRANCH="${OH_MY_ZSH_BRANCH:-master}"


readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly GHCUP_INSTALL_URL="https://get-ghcup.haskell.org"

DRY_RUN=false
STOW_ONLY=false
UPDATE_PROFILE=true
PROFILE_CHANGED=false
PROFILE_CHANGE_PLANNED=false
CUSTOM_SELECTION=false
HOMEBREW_READY=false
BREW_BUNDLE_READY=false
STOW_READY=false
MISE_READY=false
BREW_BIN=""
MISE_BIN=""
GHCUP_BIN=""
MISE_CONFIG_BACKUP=""
MISE_CONFIG_MOVED=false
DOWNLOADED_SCRIPT=""

STOW_PACKAGES=(
    aerospace
    alacritty
    emacs
    fzf
    ghostty
    git
    kvim
    mise
    nvim
    pi
    tmux
    vim
    yazi
    zed
    zsh
)

SOFTWARE_COMPONENTS=(
    brew
    stow
    haskell
)

DEFAULT_COMPONENTS=(
    brew
    zsh
    alacritty
    fzf
    tmux
    pi
    zed
    mise
    haskell
)

DEFAULT_STOW_PACKAGES=(
    zsh
    alacritty
    fzf
    mise
    tmux
    pi
    zed
)

REQUESTED_COMPONENTS=()
TEMP_FILES=()
INSTALLED_ITEMS=()
SKIPPED_ITEMS=()
STOWED_ITEMS=()
PLANNED_ITEMS=()

FMT_RED=""
FMT_GREEN=""
FMT_YELLOW=""
FMT_BLUE=""
FMT_BOLD=""
FMT_RESET=""

setup_colors() {
    if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
        FMT_RED=$'\033[31m'
        FMT_GREEN=$'\033[32m'
        FMT_YELLOW=$'\033[33m'
        FMT_BLUE=$'\033[34m'
        FMT_BOLD=$'\033[1m'
        FMT_RESET=$'\033[0m'
    fi
}

log_info() {
    printf '%sInfo:%s %s\n' "$FMT_BLUE" "$FMT_RESET" "$*" >&2
}

log_success() {
    printf '%sSuccess:%s %s\n' "$FMT_GREEN" "$FMT_RESET" "$*" >&2
}

log_warning() {
    printf '%sWarning:%s %s\n' "$FMT_YELLOW" "$FMT_RESET" "$*" >&2
}

log_error() {
    printf '%s%sError:%s %s\n' "$FMT_BOLD" "$FMT_RED" "$FMT_RESET" "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

print_command() {
    local argument

    printf '%sDry run:%s' "$FMT_YELLOW" "$FMT_RESET" >&2
    for argument in "$@"; do
        printf ' %q' "$argument" >&2
    done
    printf '\n' >&2
}

run() {
    if [[ "$DRY_RUN" == true ]]; then
        print_command "$@"
        return 0
    fi

    "$@"
}

cleanup() {
    local file

    for file in "${TEMP_FILES[@]-}"; do
        if [[ -n "$file" && -e "$file" ]]; then
            rm -f -- "$file" || true
        fi
    done
}

on_error() {
    local line="$1"
    local command="$2"
    local status="$3"

    log_error "Command failed with status ${status} at line ${line}: ${command}"
    exit "$status"
}

trap cleanup EXIT
trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local command="$1"
    local guidance="${2:-Install it and rerun ${SCRIPT_NAME}.}"

    command_exists "$command" || die "Required command '${command}' was not found. ${guidance}"
}

record_installed() {
    INSTALLED_ITEMS+=("$1")
}

record_skipped() {
    SKIPPED_ITEMS+=("$1")
}

record_stowed() {
    STOWED_ITEMS+=("$1")
}

record_planned() {
    PLANNED_ITEMS+=("$1")
}

contains_item() {
    local needle="$1"
    shift
    local item

    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

is_stow_package() {
    contains_item "$1" "${STOW_PACKAGES[@]}"
}

is_software_component() {
    contains_item "$1" "${SOFTWARE_COMPONENTS[@]}"
}

is_known_component() {
    is_stow_package "$1" || is_software_component "$1"
}

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

add_requested_components() {
    local list="$1"
    local item
    local parsed=()

    [[ -n "$list" ]] || die "--packages requires at least one package name."
    IFS=',' read -r -a parsed <<< "$list"
    for item in "${parsed[@]-}"; do
        item="$(trim_whitespace "$item")"
        [[ -n "$item" ]] || die "--packages contains an empty package name."

        if ! contains_item "$item" "${REQUESTED_COMPONENTS[@]-}"; then
            REQUESTED_COMPONENTS+=("$item")
        fi
    done
}

print_help() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Provision this macOS development environment and deploy its GNU Stow packages.
Running without options installs the default environment.

Options:
  --packages LIST       Install comma-separated components or Stow packages.
                        Brewfile-backed components apply the complete Brewfile.
                        Example: --packages zsh,tmux,nvim
  --stow-only           Deploy configuration without installing software.
  --dry-run             Print operations without changing the system.
  --no-profile-update   Do not add shell initialization lines.
  -h, --help            Show this help message.

Default components:
  ${DEFAULT_COMPONENTS[*]}

Available Stow packages:
  ${STOW_PACKAGES[*]}

Software-only components:
  ${SOFTWARE_COMPONENTS[*]}

Declarative package files:
  Homebrew: ${BREWFILE}
  mise:     ${MISE_CONFIG_SOURCE}

Profile override:
  LOGIN_PROFILE_FILE=${LOGIN_PROFILE_FILE}

Other supported overrides include ZSH, ZSH_CUSTOM, OH_MY_ZSH_REMOTE,
and OH_MY_ZSH_BRANCH.
EOF
}

parse_arguments() {
    while (($# > 0)); do
        case "$1" in
            --packages)
                (($# >= 2)) || die "--packages requires a comma-separated value."
                CUSTOM_SELECTION=true
                add_requested_components "$2"
                shift 2
                ;;
            --packages=*)
                CUSTOM_SELECTION=true
                add_requested_components "${1#*=}"
                shift
                ;;
            --stow-only)
                STOW_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-profile-update)
                UPDATE_PROFILE=false
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            --)
                shift
                (($# == 0)) || die "Unexpected positional arguments: $*"
                ;;
            -* )
                die "Unknown option: $1. Run '${SCRIPT_NAME} --help' for usage."
                ;;
            *)
                die "Unexpected positional argument: $1. Use --packages to select components."
                ;;
        esac
    done
}

select_default_components() {
    if [[ "$CUSTOM_SELECTION" == true ]]; then
        return
    fi

    if [[ "$STOW_ONLY" == true ]]; then
        REQUESTED_COMPONENTS=("${DEFAULT_STOW_PACKAGES[@]}")
    else
        REQUESTED_COMPONENTS=("${DEFAULT_COMPONENTS[@]}")
    fi
}

validate_selection() {
    local component

    ((${#REQUESTED_COMPONENTS[@]} > 0)) || die "No components were selected."

    for component in "${REQUESTED_COMPONENTS[@]}"; do
        is_known_component "$component" || die "Unknown component '${component}'. Run '${SCRIPT_NAME} --help' for available names."

        if [[ "$STOW_ONLY" == true ]] && ! is_stow_package "$component"; then
            die "Component '${component}' has no Stow package and cannot be used with --stow-only."
        fi
    done
}

validate_environment() {
    [[ "$(uname -s)" == "Darwin" ]] || die "This installer currently supports macOS only."
    [[ -d "$REPO_ROOT/.git" ]] || log_warning "${REPO_ROOT} does not appear to be a Git checkout."
}

ensure_profile_line() {
    local profile_file="$1"
    local line="$2"
    local last_character=""

    if [[ "$UPDATE_PROFILE" != true ]]; then
        log_info "Profile update disabled; add this line to ${profile_file} if needed: ${line}"
        return
    fi

    if [[ -f "$profile_file" ]] && grep -Fqx -- "$line" "$profile_file"; then
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would append to ${profile_file}: ${line}"
        record_planned "profile:${profile_file}"
        PROFILE_CHANGE_PLANNED=true
        return
    fi

    mkdir -p -- "$(dirname -- "$profile_file")"

    if [[ -s "$profile_file" ]]; then
        last_character="$(tail -c 1 "$profile_file" 2>/dev/null || true)"
        if [[ -n "$last_character" ]]; then
            printf '\n' >> "$profile_file"
        fi
    fi

    printf '%s\n' "$line" >> "$profile_file"
    PROFILE_CHANGED=true
    log_success "Updated ${profile_file}"
}

ensure_login_profile_line() {
    ensure_profile_line "$LOGIN_PROFILE_FILE" "$1"
}


download_script() {
    local url="$1"
    local label="$2"
    local temporary_file

    require_command curl "curl is included with macOS; verify your system installation."

    if [[ "$DRY_RUN" == true ]]; then
        DOWNLOADED_SCRIPT="<downloaded-${label}-installer>"
        print_command curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 "$url" --output "$DOWNLOADED_SCRIPT"
        return
    fi

    temporary_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
    TEMP_FILES+=("$temporary_file")
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 "$url" --output "$temporary_file"
    DOWNLOADED_SCRIPT="$temporary_file"
}

load_homebrew() {
    local candidate
    local shell_environment

    if command_exists brew; then
        BREW_BIN="$(command -v brew)"
        if "$BREW_BIN" --version >/dev/null 2>&1; then
            return 0
        fi
        BREW_BIN=""
    fi

    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [[ -x "$candidate" ]] || continue

        if [[ "$DRY_RUN" == true ]]; then
            BREW_BIN="$candidate"
            return 0
        fi

        if ! shell_environment="$("$candidate" shellenv)"; then
            continue
        fi
        if ! eval "$shell_environment"; then
            continue
        fi
        if ! "$candidate" --version >/dev/null 2>&1; then
            continue
        fi

        BREW_BIN="$candidate"
        return 0
    done

    return 1
}

configure_homebrew_profile() {
    local line
    local quoted_brew_bin

    [[ -n "$BREW_BIN" ]] || return
    printf -v quoted_brew_bin '%q' "$BREW_BIN"
    line="eval \"\$(${quoted_brew_bin} shellenv)\""
    ensure_login_profile_line "$line"
}

ensure_homebrew() {
    if [[ "$HOMEBREW_READY" == true ]]; then
        return
    fi

    if load_homebrew; then
        log_info "Homebrew is already installed at ${BREW_BIN}."
        record_skipped "homebrew"
    else
        log_info "Installing Homebrew..."
        download_script "$HOMEBREW_INSTALL_URL" homebrew
        run env NONINTERACTIVE=1 /bin/bash "$DOWNLOADED_SCRIPT"

        if [[ "$DRY_RUN" == true ]]; then
            if [[ "$(uname -m)" == "arm64" ]]; then
                BREW_BIN="/opt/homebrew/bin/brew"
            else
                BREW_BIN="/usr/local/bin/brew"
            fi
            record_planned "homebrew"
        else
            load_homebrew || die "Homebrew installation finished, but 'brew' could not be loaded."
            record_installed "homebrew"
            log_success "Homebrew installed."
        fi
    fi

    configure_homebrew_profile
    HOMEBREW_READY=true
}

ensure_brew_bundle() {
    if [[ "$BREW_BUNDLE_READY" == true ]]; then
        return
    fi

    ensure_homebrew
    [[ -f "$BREWFILE" ]] || die "Brewfile is missing: ${BREWFILE}"

    if [[ -x "$BREW_BIN" ]] \
        && env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 \
            "$BREW_BIN" bundle check --no-upgrade --file "$BREWFILE" >/dev/null 2>&1; then
        log_info "All Brewfile dependencies are already installed."
        record_skipped "brew-bundle"
    else
        log_info "Installing dependencies declared in ${BREWFILE}..."
        run env \
            HOMEBREW_NO_AUTO_UPDATE=1 \
            HOMEBREW_BUNDLE_NO_UPGRADE=1 \
            "$BREW_BIN" bundle install --no-upgrade --file "$BREWFILE"

        if [[ "$DRY_RUN" == true ]]; then
            record_planned "brew-bundle"
        else
            env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 \
                "$BREW_BIN" bundle check --no-upgrade --file "$BREWFILE" >/dev/null 2>&1 \
                || die "Homebrew Bundle did not install every Brewfile dependency."
            record_installed "brew-bundle"
            log_success "Installed Brewfile dependencies."
        fi
    fi

    BREW_BUNDLE_READY=true
}

ensure_stow() {
    if [[ "$STOW_READY" == true ]]; then
        return
    fi

    if command_exists stow; then
        STOW_READY=true
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "GNU Stow is not installed; the dry run cannot validate Stow conflicts."
        STOW_READY=true
        return
    fi

    if [[ "$STOW_ONLY" == true ]]; then
        die "GNU Stow is required for --stow-only. Apply '${BREWFILE}' first with Homebrew Bundle."
    fi

    ensure_brew_bundle
    command_exists stow || die "Brewfile installation completed, but GNU Stow is unavailable."
    STOW_READY=true
}

stow_package() {
    local package="$1"

    is_stow_package "$package" || die "'${package}' is not a registered Stow package."
    [[ -d "$REPO_ROOT/$package" ]] || die "Stow package directory is missing: ${REPO_ROOT}/${package}"

    ensure_stow
    if [[ "$package" == "zsh" ]]; then
        cleanup_generated_shell_profiles
    elif [[ "$package" == "mise" ]]; then
        migrate_mise_config
    fi

    log_info "Deploying Stow package '${package}'..."
    if [[ "$DRY_RUN" == true ]]; then
        print_command stow --dir "$REPO_ROOT" --target "$HOME" --restow "$package"
        record_planned "stow:${package}"
        return
    fi

    if ! stow --dir "$REPO_ROOT" --target "$HOME" --restow "$package"; then
        if [[ "$package" == "mise" ]]; then
            restore_mise_config
        fi
        die "Failed to deploy Stow package '${package}'."
    fi

    MISE_CONFIG_MOVED=false
    record_stowed "$package"
    log_success "Deployed '${package}'."
}

require_git() {
    local git_path

    if ! command_exists git; then
        if [[ "$DRY_RUN" == true ]]; then
            log_warning "Git is not installed; cloning commands cannot be validated during this dry run."
            return
        fi
        die "Git is required. Install the Xcode Command Line Tools with 'xcode-select --install'."
    fi

    git_path="$(command -v git)"
    if [[ "$git_path" == "/usr/bin/git" ]] && ! xcode-select -p >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == true ]]; then
            log_warning "The Xcode Command Line Tools are missing; Git clones are shown but not validated."
            return
        fi
        die "The Xcode Command Line Tools are required. Install them with 'xcode-select --install'."
    fi

    if [[ "$DRY_RUN" != true ]] && ! git --version >/dev/null 2>&1; then
        die "Git was found at '${git_path}', but it is not usable."
    fi
}

clone_repository() {
    local url="$1"
    local destination="$2"
    local label="$3"
    local branch="${4:-}"
    local parent
    local clone_command=(git clone --depth 1)

    if [[ -d "$destination/.git" ]]; then
        log_info "${label} is already installed."
        record_skipped "$label"
        return
    fi

    if [[ -e "$destination" ]]; then
        die "Cannot install ${label}: '${destination}' exists but is not a Git checkout."
    fi

    require_git
    parent="$(dirname -- "$destination")"
    run mkdir -p -- "$parent"

    if [[ -n "$branch" ]]; then
        clone_command+=(--branch "$branch")
    fi
    clone_command+=("$url" "$destination")

    log_info "Installing ${label}..."
    run "${clone_command[@]}"

    if [[ "$DRY_RUN" == true ]]; then
        record_planned "$label"
    else
        [[ -d "$destination/.git" ]] || die "Git clone for ${label} did not produce a valid checkout."
        record_installed "$label"
        log_success "Installed ${label}."
    fi
}

install_oh_my_zsh() {
    if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
        log_info "Oh My Zsh is already installed."
        record_skipped "oh-my-zsh"
        return
    fi

    if [[ -e "$ZSH" ]]; then
        die "Cannot install Oh My Zsh: '${ZSH}' exists but is not a valid installation."
    fi

    clone_repository "$OH_MY_ZSH_REMOTE" "$ZSH" "oh-my-zsh" "$OH_MY_ZSH_BRANCH"
}

install_zsh_plugins() {
    clone_repository \
        "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
        "zsh-syntax-highlighting"

    clone_repository \
        "https://github.com/zsh-users/zsh-autosuggestions.git" \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
        "zsh-autosuggestions"
}

install_z_directory_jumper() {
    clone_repository \
        "https://github.com/rupa/z.git" \
        "$HOME/.config/z" \
        "z"
}

install_tmux_plugin_manager() {
    clone_repository \
        "https://github.com/tmux-plugins/tpm.git" \
        "$HOME/.tmux/plugins/tpm" \
        "tmux-plugin-manager"
}

profile_contains_only_installer_lines() {
    local profile_file="$1"
    local profile_kind="$2"
    local line
    local found_line=false

    [[ -f "$profile_file" && ! -L "$profile_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue

        if [[ "$profile_kind" == "zshenv" ]]; then
            if [[ "$line" != 'export PATH="$HOME/.local/share/mise/shims:$PATH"' \
                && "$line" != 'export PATH="$HOME/.ghcup/bin:$PATH"' ]]; then
                return 1
            fi
        elif [[ "$profile_kind" == "zshrc" ]]; then
            if [[ "$line" != 'eval "$(/opt/homebrew/bin/mise activate zsh)"' \
                && "$line" != 'eval "$(/usr/local/bin/mise activate zsh)"' \
                && "$line" != 'export PATH="$HOME/.ghcup/bin:$PATH"' ]]; then
                return 1
            fi
        else
            return 1
        fi

        found_line=true
    done < "$profile_file"

    [[ "$found_line" == true ]]
}

cleanup_generated_shell_profiles() {
    if profile_contains_only_installer_lines "$HOME/.zshenv" zshenv; then
        log_info "Removing installer-generated ~/.zshenv before Stow takes ownership."
        run rm -f -- "$HOME/.zshenv"
    fi

    if profile_contains_only_installer_lines "$HOME/.zshrc" zshrc; then
        log_info "Removing installer-generated ~/.zshrc before Stow takes ownership."
        run rm -f -- "$HOME/.zshrc"
    fi
}

install_zsh_component() {
    install_oh_my_zsh
    stow_package zsh
    install_zsh_plugins
}

install_alacritty_component() {
    ensure_brew_bundle
    stow_package alacritty
}

install_fzf_component() {
    ensure_brew_bundle
    install_z_directory_jumper
    stow_package fzf
}

install_tmux_component() {
    ensure_brew_bundle
    install_tmux_plugin_manager
    stow_package tmux
}

configure_mise_shell() {
    local quoted_mise_bin
    local shim_line='export PATH="$HOME/.local/share/mise/shims:$PATH"'

    ensure_login_profile_line "$shim_line"

    if contains_item zsh "${REQUESTED_COMPONENTS[@]-}" \
        && grep -Fq -- 'mise activate zsh' "$REPO_ROOT/zsh/.zshrc"; then
        return
    fi

    ensure_profile_line "$HOME/.zshenv" "$shim_line"
    if [[ -f "$HOME/.zshrc" ]] && grep -Fq -- 'mise activate zsh' "$HOME/.zshrc"; then
        return
    fi

    printf -v quoted_mise_bin '%q' "$MISE_BIN"
    ensure_profile_line "$HOME/.zshrc" "eval \"\$(${quoted_mise_bin} activate zsh)\""
}

migrate_mise_config() {
    [[ -f "$MISE_CONFIG_SOURCE" ]] || die "mise config is missing: ${MISE_CONFIG_SOURCE}"

    if [[ -L "$MISE_CONFIG_TARGET" || ! -e "$MISE_CONFIG_TARGET" ]]; then
        return
    fi
    if [[ ! -f "$MISE_CONFIG_TARGET" ]]; then
        die "Cannot migrate mise config: ${MISE_CONFIG_TARGET} is not a regular file."
    fi

    MISE_CONFIG_BACKUP="${MISE_CONFIG_TARGET}.backup-$(date '+%Y%m%d%H%M%S')-$$"
    [[ ! -e "$MISE_CONFIG_BACKUP" ]] || die "Refusing to overwrite existing backup: ${MISE_CONFIG_BACKUP}"

    log_warning "Moving the existing mise config to ${MISE_CONFIG_BACKUP} before Stow takes ownership."
    run mv -- "$MISE_CONFIG_TARGET" "$MISE_CONFIG_BACKUP"
    if [[ "$DRY_RUN" != true ]]; then
        MISE_CONFIG_MOVED=true
    fi
}

restore_mise_config() {
    if [[ "$MISE_CONFIG_MOVED" != true || ! -f "$MISE_CONFIG_BACKUP" ]]; then
        return
    fi

    log_warning "Stow failed; restoring the previous mise config."
    if [[ -L "$MISE_CONFIG_TARGET" ]]; then
        rm -f -- "$MISE_CONFIG_TARGET"
    elif [[ -e "$MISE_CONFIG_TARGET" ]]; then
        log_error "Cannot restore mise config because the target was recreated: ${MISE_CONFIG_TARGET}"
        return
    fi

    mkdir -p -- "$(dirname -- "$MISE_CONFIG_TARGET")"
    mv -- "$MISE_CONFIG_BACKUP" "$MISE_CONFIG_TARGET"
    MISE_CONFIG_MOVED=false
    log_success "Restored ${MISE_CONFIG_TARGET}."
}

install_mise_component() {
    local homebrew_prefix

    if [[ "$MISE_READY" == true ]]; then
        return
    fi

    ensure_brew_bundle
    if [[ "$DRY_RUN" == true && ! -x "$BREW_BIN" ]]; then
        homebrew_prefix="$(dirname -- "$(dirname -- "$BREW_BIN")")"
    else
        homebrew_prefix="$("$BREW_BIN" --prefix)"
    fi
    MISE_BIN="$homebrew_prefix/bin/mise"

    if [[ "$DRY_RUN" != true && ! -x "$MISE_BIN" ]]; then
        die "Brewfile installation completed, but '${MISE_BIN}' is unavailable."
    fi

    stow_package mise
    configure_mise_shell

    log_info "Trusting and installing tools declared in ${MISE_CONFIG_SOURCE}..."
    run "$MISE_BIN" trust --yes "$MISE_CONFIG_SOURCE"
    run "$MISE_BIN" install --yes --cd "$REPO_ROOT"

    if [[ "$DRY_RUN" == true ]]; then
        record_planned "mise-tools"
    else
        record_installed "mise-tools"
        log_success "Installed tools declared by the global mise config."
    fi

    MISE_READY=true
}

configure_ghcup_shell() {
    local path_line='export PATH="$HOME/.ghcup/bin:$PATH"'

    ensure_login_profile_line '[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"'
    ensure_login_profile_line "$path_line"

    if contains_item zsh "${REQUESTED_COMPONENTS[@]-}" \
        && grep -Fq -- "$path_line" "$REPO_ROOT/zsh/.zshenv" \
        && grep -Fq -- "$path_line" "$REPO_ROOT/zsh/.zshrc"; then
        return
    fi

    ensure_profile_line "$HOME/.zshenv" "$path_line"
    ensure_profile_line "$HOME/.zshrc" "$path_line"
}

load_ghcup_environment() {
    if [[ "$DRY_RUN" == true || ! -f "$HOME/.ghcup/env" ]]; then
        return
    fi

    set +u
    # shellcheck disable=SC1091
    . "$HOME/.ghcup/env"
    set -u
}

find_ghcup() {
    if [[ -x "$HOME/.ghcup/bin/ghcup" ]]; then
        GHCUP_BIN="$HOME/.ghcup/bin/ghcup"
        return 0
    fi

    return 1
}

ensure_haskell_tool() {
    local ghcup_name="$1"
    local executable="$2"

    if [[ -x "$HOME/.ghcup/bin/$executable" ]]; then
        log_info "Haskell tool '${ghcup_name}' is already installed."
        record_skipped "$ghcup_name"
        return
    fi

    log_info "Installing Haskell tool '${ghcup_name}'..."
    run "$GHCUP_BIN" install "$ghcup_name"
    if [[ "$ghcup_name" == "ghc" ]]; then
        run "$GHCUP_BIN" set ghc recommended
    fi

    if [[ "$DRY_RUN" == true ]]; then
        record_planned "$ghcup_name"
    else
        [[ -x "$HOME/.ghcup/bin/$executable" ]] || die "GHCup installed '${ghcup_name}', but '${executable}' is unavailable under ~/.ghcup/bin."
        record_installed "$ghcup_name"
        log_success "Installed Haskell tool '${ghcup_name}'."
    fi
}

install_haskell_tools() {
    configure_ghcup_shell
    load_ghcup_environment

    if find_ghcup; then
        log_info "GHCup is already installed."
        record_skipped "ghcup"
    else
        log_info "Installing GHCup..."
        download_script "$GHCUP_INSTALL_URL" ghcup
        run env \
            BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
            BOOTSTRAP_HASKELL_ADJUST_BASHRC=0 \
            /bin/sh "$DOWNLOADED_SCRIPT"

        if [[ "$DRY_RUN" == true ]]; then
            GHCUP_BIN="$HOME/.ghcup/bin/ghcup"
            record_planned "ghcup"
        else
            load_ghcup_environment
            find_ghcup || die "GHCup installation finished, but 'ghcup' is unavailable."
            record_installed "ghcup"
            log_success "Installed GHCup."
        fi
    fi

    ensure_haskell_tool ghc ghc
    ensure_haskell_tool cabal cabal
    ensure_haskell_tool hls haskell-language-server-wrapper
}

install_component() {
    local component="$1"

    case "$component" in
        brew)
            ensure_brew_bundle
            ;;
        stow)
            ensure_stow
            ;;
        mise)
            install_mise_component
            ;;
        zsh)
            install_zsh_component
            ;;
        alacritty)
            install_alacritty_component
            ;;
        fzf)
            install_fzf_component
            ;;

        tmux)
            install_tmux_component
            ;;
        haskell)
            install_haskell_tools
            ;;

        *)
            stow_package "$component"
            ;;
    esac
}

print_items() {
    local title="$1"
    shift
    local item
    local separator=""
    local printed=false

    for item in "$@"; do
        [[ -n "$item" ]] || continue
        if [[ "$printed" == false ]]; then
            printf '%s:' "$title" >&2
            printed=true
        fi
        printf '%s %s' "$separator" "$item" >&2
        separator=","
    done

    if [[ "$printed" == true ]]; then
        printf '\n' >&2
    fi
}

print_summary() {
    printf '\n' >&2
    if [[ "$DRY_RUN" == true ]]; then
        log_success "Dry run completed; no changes were made."
        print_items "Planned" "${PLANNED_ITEMS[@]-}"
    else
        log_success "Bootstrap completed."
        print_items "Installed" "${INSTALLED_ITEMS[@]-}"
        print_items "Stowed" "${STOWED_ITEMS[@]-}"
        print_items "Already present" "${SKIPPED_ITEMS[@]-}"
    fi

    if [[ "$DRY_RUN" != true && "$PROFILE_CHANGED" == true ]]; then
        log_info "Open a new login shell to load the profile updates."
    elif [[ "$DRY_RUN" == true && "$PROFILE_CHANGE_PLANNED" == true ]]; then
        log_info "Profile updates are included in the plan and were not written."
    fi
}

main() {
    local component

    setup_colors
    parse_arguments "$@"
    select_default_components
    validate_selection
    validate_environment

    log_info "Repository: ${REPO_ROOT}"
    log_info "Selected components: ${REQUESTED_COMPONENTS[*]}"

    if [[ "$STOW_ONLY" != true ]] && contains_item brew "${REQUESTED_COMPONENTS[@]}"; then
        install_component brew
    fi
    if [[ "$STOW_ONLY" != true ]] && contains_item zsh "${REQUESTED_COMPONENTS[@]}"; then
        install_component zsh
    fi

    for component in "${REQUESTED_COMPONENTS[@]}"; do
        if [[ "$STOW_ONLY" == true ]]; then
            stow_package "$component"
        elif [[ "$component" != "brew" && "$component" != "zsh" && "$component" != "haskell" ]]; then
            install_component "$component"
        fi
    done

    if [[ "$STOW_ONLY" != true ]] && contains_item haskell "${REQUESTED_COMPONENTS[@]}"; then
        install_component haskell
    fi

    print_summary
}

main "$@"
