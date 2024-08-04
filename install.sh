#!bin/sh

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.zsh-custom}"

# Default settings
REPO=${REPO:-ohmyzsh/ohmyzsh}
REMOTE=${REMOTE:-https://github.com/${REPO}.git}
BRANCH=${BRANCH:-master}

command_exists() {
    command -v "$@" >/dev/null 2>&1
}

fmt_error() {
    printf '%sError: %s%s\n' "${FMT_BOLD}${FMT_RED}" "$*" "$FMT_RESET" >&2
}

setup_color() {
  # Only use colors if connected to a terminal
  if ! is_tty; then
    FMT_RAINBOW=""
    FMT_RED=""
    FMT_GREEN=""
    FMT_YELLOW=""
    FMT_BLUE=""
    FMT_BOLD=""
    FMT_RESET=""
    return
  fi

  if supports_truecolor; then
    FMT_RAINBOW="
      $(printf '\033[38;2;255;0;0m')
      $(printf '\033[38;2;255;97;0m')
      $(printf '\033[38;2;247;255;0m')
      $(printf '\033[38;2;0;255;30m')
      $(printf '\033[38;2;77;0;255m')
      $(printf '\033[38;2;168;0;255m')
      $(printf '\033[38;2;245;0;172m')
    "
  else
    FMT_RAINBOW="
      $(printf '\033[38;5;196m')
      $(printf '\033[38;5;202m')
      $(printf '\033[38;5;226m')
      $(printf '\033[38;5;082m')
      $(printf '\033[38;5;021m')
      $(printf '\033[38;5;093m')
      $(printf '\033[38;5;163m')
    "
  fi

  FMT_RED=$(printf '\033[31m')
  FMT_GREEN=$(printf '\033[32m')
  FMT_YELLOW=$(printf '\033[33m')
  FMT_BLUE=$(printf '\033[34m')
  FMT_BOLD=$(printf '\033[1m')
  FMT_RESET=$(printf '\033[0m')
}

zsh_install() {
    command_exists git || {
        fmt_error "git is not installed"
        exit 1
    }

    if [ -d "$ZSH" ]; then
        return
    fi

    # Manual clone with git config options to support git < v1.7.2
    git init --quiet "$ZSH" && cd "$ZSH" \
    && git config core.eol lf \
    && git config core.autocrlf false \
    && git config fsck.zeroPaddedFilemode ignore \
    && git config fetch.fsck.zeroPaddedFilemode ignore \
    && git config receive.fsck.zeroPaddedFilemode ignore \
    && git config oh-my-zsh.remote origin \
    && git config oh-my-zsh.branch "$BRANCH" \
    && git remote add origin "$REMOTE" \
    && git fetch --depth=1 origin \
    && git checkout -b "$BRANCH" "origin/$BRANCH" || {
        [ ! -d "$ZSH" ] || {
        cd -
        rm -rf "$ZSH" 2>/dev/null
        }
        fmt_error "git clone of oh-my-zsh repo failed"
        exit 1
    }
    # Exit installation directory
    cd -

    echo
}

setup_zsh_config() {
    command_exists stow || {
        fmt_error "stow is not installed"
        exit 1
    }

    stow zsh || {
        fmt_error "stow zsh failed"
        exit 1
    }
}


zsh_plugin_install() {
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting || {
        fmt_error "git clone of zsh-syntax-highting repo failed"
        exit 1
    }

    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions || {
        fmt_error "git clone of zsh-autosuggestions repo failed"
        exit 1
    }
}

main() {

    zsh_install
    setup_zsh_config
    zsh_plugin_install

}

main "$@"