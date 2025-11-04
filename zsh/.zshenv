
# https://mirrors.ustc.edu.cn/help/homebrew-bottles.html
# add ustc brew source
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"

# add llvm to path
# export PATH="/usr/local/opt/llvm/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/development/flutter/bin:$PATH"
export PATH="$PATH:$HOME/Library/Python/3.9/bin"
. "$HOME/.cargo/env"

export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools

export MY_PING_PATH=/Applications/SASE.app/Contents/Services
export PATH=${MY_PING_PATH}:$PATH
export ANDROID_STUDIO_BIN=/Applications/Android\ Studio.app/Contents/MacOS
export PATH=${ANDROID_STUDIO_BIN}:$PATH

# Android Studio's JDK path
# export JAVA_HOME=/Applications/Android\ Studio.app/Contents/jbr/Contents/Home
export EDITOR=nvim

# ZVM
export ZVM_INSTALL="$HOME/.zvm/self"
export PATH="$PATH:$HOME/.zvm/bin"
export PATH="$PATH:$ZVM_INSTALL/"
