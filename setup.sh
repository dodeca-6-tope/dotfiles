#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"

# --- packages ---
if [ "$OS" == "Darwin" ]; then
  if [ ! -f /opt/homebrew/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew bundle install --file=~/Brewfile

  # macOS defaults
  defaults write com.apple.WindowManager GloballyEnabled -bool true
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock showAppSuggestions -bool false
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string clmv
  dockutil --remove all --no-restart &>/dev/null
  for app in \
    "/System/Applications/System Settings.app" \
    "/Applications/Slack.app" \
    "/Applications/Ghostty.app" \
    "/Applications/1Password.app" \
    "/Applications/Google Chrome.app" \
    "/Applications/WhatsApp.app" \
    "/Applications/Visual Studio Code.app" \
    "/System/Applications/Utilities/Activity Monitor.app"; do
    dockutil --add "$app" --no-restart &>/dev/null
  done
  dockutil --add ~/Downloads --view fan --display stack &>/dev/null

elif [ "$OS" == "Linux" ]; then
  export PATH="$HOME/.local/bin:$PATH"
  mkdir -p "$HOME/.local/bin"
  DPKG_ARCH="$(dpkg --print-architecture)"          # amd64 | arm64
  case "$DPKG_ARCH" in amd64) RUST_ARCH=x86_64 ;; arm64) RUST_ARCH=aarch64 ;; esac
  gh_latest() { curl -s "https://api.github.com/repos/$1/releases/latest" | jq -r '.tag_name'; }

  sudo apt update -qq
  sudo apt install -y -qq curl ffmpeg git jq tree unzip wget zsh

  # Portable binaries -> ~/.local/bin: on the ephemeral container rootfs only $HOME
  # survives reboots, so these must not go under /usr.

  # tmux (static build)
  if ! command -v tmux &>/dev/null; then
    TMUX_VER=$(gh_latest mjakob-gh/build-static-tmux)
    curl -sL "https://github.com/mjakob-gh/build-static-tmux/releases/download/${TMUX_VER}/tmux.linux-${DPKG_ARCH}.stripped.gz" | gzip -dc > "$HOME/.local/bin/tmux"
    chmod +x "$HOME/.local/bin/tmux"
  fi

  # fzf (apt version is too old, no --tmux support)
  if ! command -v fzf &>/dev/null; then
    FZF_VER=$(gh_latest junegunn/fzf)
    curl -sL "https://github.com/junegunn/fzf/releases/download/${FZF_VER}/fzf-${FZF_VER#v}-linux_${DPKG_ARCH}.tar.gz" | tar xz -C "$HOME/.local/bin"
  fi

  # git-delta (musl build avoids glibc issues on older distros)
  if ! command -v delta &>/dev/null; then
    DELTA_VER=$(gh_latest dandavison/delta)
    [ "$DPKG_ARCH" = amd64 ] && DELTA_TRIPLE="${RUST_ARCH}-unknown-linux-musl" || DELTA_TRIPLE="${RUST_ARCH}-unknown-linux-gnu"
    curl -sL "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/delta-${DELTA_VER}-${DELTA_TRIPLE}.tar.gz" | tar xz -C /tmp
    mv -f "/tmp/delta-${DELTA_VER}-${DELTA_TRIPLE}/delta" "$HOME/.local/bin/delta"
  fi

  # bat
  if ! command -v bat &>/dev/null; then
    BAT_VER=$(gh_latest sharkdp/bat)
    [ "$DPKG_ARCH" = amd64 ] && BAT_TRIPLE="${RUST_ARCH}-unknown-linux-musl" || BAT_TRIPLE="${RUST_ARCH}-unknown-linux-gnu"
    curl -sL "https://github.com/sharkdp/bat/releases/download/${BAT_VER}/bat-${BAT_VER}-${BAT_TRIPLE}.tar.gz" | tar xz -C /tmp
    mv -f "/tmp/bat-${BAT_VER}-${BAT_TRIPLE}/bat" "$HOME/.local/bin/bat"
  fi

  # zoxide (init in custom/zoxide.zsh)
  if ! command -v zoxide &>/dev/null; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- --bin-dir "$HOME/.local/bin"
  fi

  # gh CLI
  if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=${DPKG_ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y -qq gh
  fi
fi

# --- corepack ---
if [ "$OS" == "Darwin" ]; then
  npm install -g corepack
  corepack enable
fi

# --- gcloud ---
if ! command -v gcloud &>/dev/null; then
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)  GCLOUD_ARCHIVE="google-cloud-cli-darwin-arm.tar.gz" ;;
    Linux-x86_64)  GCLOUD_ARCHIVE="google-cloud-cli-linux-x86_64.tar.gz" ;;
    Linux-aarch64) GCLOUD_ARCHIVE="google-cloud-cli-linux-arm.tar.gz" ;;
  esac
  curl -sO "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${GCLOUD_ARCHIVE}"
  tar -xf "$GCLOUD_ARCHIVE" -C "$HOME"
  "$HOME/google-cloud-sdk/install.sh" --quiet
  rm -f "$GCLOUD_ARCHIVE"
  source "$HOME/google-cloud-sdk/path.bash.inc"
fi
gcloud auth print-identity-token &>/dev/null || gcloud auth login --no-launch-browser

# --- oh-my-zsh ---
if [ ! -d ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

# --- github ---
gh auth status > /dev/null 2>&1 || gh auth login

# --- dotfiles ---
if [ ! -d ~/.dotfiles ]; then
  git clone --bare https://github.com/dodeca-6-tope/dotfiles.git ~/.dotfiles
fi
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" fetch origin main
# Keep macOS-only files (e.g. VSCode config under ~/Library) off Linux via sparse-checkout
if [ "$OS" == "Linux" ]; then
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config core.sparseCheckout true
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config core.sparseCheckoutCone false
  printf '/*\n!/Library/\n' > "$HOME/.dotfiles/info/sparse-checkout"
fi
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" reset --hard FETCH_HEAD
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no
gh auth setup-git
git config -f ~/.gitconfig-local user.name "$(gh api user -q '.login')"
git config -f ~/.gitconfig-local user.email "$(gh api user -q '"\(.id)+\(.login)@users.noreply.github.com"')"

# --- zsh plugins ---
ZSH_PLUGINS="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
[ -d "$ZSH_PLUGINS/zsh-autosuggestions" ] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_PLUGINS/zsh-autosuggestions"
[ -d "$ZSH_PLUGINS/fzf-tab" ] || git clone --depth=1 https://github.com/Aloxaf/fzf-tab.git "$ZSH_PLUGINS/fzf-tab"

# --- powerlevel10k ---
P10K="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "$P10K" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"

# --- default shell ---
[[ "$SHELL" == */zsh ]] || chsh -s "$(which zsh)"

exec zsh -l
