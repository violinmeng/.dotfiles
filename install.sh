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

fmt_info() {
    printf '%sInfo: %s%s\n' "${FMT_GREEN}" "$*" "$FMT_RESET" >&2
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

brew_install() {
    command_exists brew || {
        # install brew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        command_exists brew || {
            fmt_error "try to install brew but failed. please install brew manually and re-run this script."
            exit 1
        }
    }

    fmt_info "brew installed"
}

brew_installer() {
    local package="$1"
    local cmd="${2:-$1}"
    if [[ -n "${cmd}" ]]; then
        command_exists "$cmd" || {
            brew install "$package"
            command_exists "$cmd" || {
                fmt_error "try to install $package with brew, but failed."
                exit 1
            }
        }
        fmt_info "$package installed"
    else
        fmt_error "function brew_installer should have one parameter at least"
    fi
}

stow_config() {
    local config="$1"

    if [[ -n "$config" ]]; then
        command_exists stow || {
            fmt_error "stow is not installed"
            exit 1
        }
        stow "$config" || {
            fmt_error "stow $config failed"
            exit 1
        }
        fmt_info "stow $config finished"
    else
        fmt_error "function stow_config should have one parameter"
    fi
}

rust_installer() {
    command_exists cargo || {
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        fmt_info "install rust toolchain finished, Need restart current terminal."
    }
}

nvm_installer() {
    command_exists nvm || {
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        fmt_info "install nvm finished."
    }
}

node_installer() {
    command_exists node || {
        nvm install node
        fmt_info "install node finished."
    }
}

rvm_installer() {
    command_exists rvm || {
        curl -sSL https://get.rvm.io | bash -s stable
        fmt_info "install rvm finished."
    }
}

ruby_installer() {
    # install ruby version 3 above, need extra params;
    1 || {
        rvm install 3.3.5 --with-openssl-dir=`brew --prefix openssl`
    }
}

zsh_install() {
    command_exists git || {
        fmt_error "git is not installed"
        exit 1
    }

    if [[ -d "$ZSH" ]]; then
        fmt_info "oh-my-zsh has installed"
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

zsh_plugin_install() {
    if [[ -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]]; then
        fmt_info "zsh-syntax-highlighting has installed"
    else
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting || {
            fmt_error "git clone of zsh-syntax-highting repo failed"
            exit 1
        }
    fi
    

    if [[ -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]]; then
        fmt_info "zsh-autosuggestions has installed"
    else
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions || {
            fmt_error "git clone of zsh-autosuggestions repo failed"
            exit 1
        }
    fi
    
}

z_install() {   
    if [[ -d "${HOME}/.config/z" ]]; then
        fmt_info "z has installed"
        return
    fi

    git clone git@github.com:rupa/z.git ${HOME}/.config/z || {
        fmt_error "git clone of z repo failed"
        exit 1
    }
}

alacritty_install() {
    command_exists alacritty || {
        brew install --cask alacritty
        command_exists alacritty || {
            fmt_error "try to install alacritty with brew, but failed."
            exit 1
        }
    }
    fmt_info "alacritty has installed"
}

tmux_plugin_install() {
    if [[ -d "${HOME}/.tmux/plugins/tpm" ]]; then
        fmt_info "tmux plugin manager has installed"
        return
    fi

    git clone git@github.com:tmux-plugins/tpm ${HOME}/.tmux/plugins/tpm || {
        fmt_error "git clone of tmux plugin manager repo failed"
        exit 1
    }
}

main() {

    # install Macos brew package manager.
    brew_install

    # install stow with brew. we can not setup these configration without this tools.
    brew_installer stow
    
    # oh-my-zsh config and add custom config
    zsh_install
    stow_config zsh
    zsh_plugin_install

    # install alacritty
    alacritty_install
    stow_config alacritty

    # fzf
    brew_installer fzf
    brew_installer fd
    z_install
    stow_config fzf

    # ripgrep
    brew_installer ripgrep rg

    # tmux
    tmux_plugin_install
    stow_config tmux

}

test() {
    tmux_plugin_install
    stow_config tmux
}

main "$@"
# test "$@"