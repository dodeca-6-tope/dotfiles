#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin | Linux) ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- bootstrap ---
# Just enough of a toolchain to check out the dotfiles below.
if [ "$OS" == "Darwin" ]; then
  case "$ARCH" in
    arm64) BREW_BIN="/opt/homebrew/bin/brew" ;;
    x86_64) BREW_BIN="/usr/local/bin/brew" ;;
    *)
      echo "Unsupported macOS architecture: $ARCH" >&2
      exit 1
      ;;
  esac
  if [ ! -x "$BREW_BIN" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$("$BREW_BIN" shellenv)"

elif [ "$OS" == "Linux" ]; then
  export PATH="$HOME/.local/bin:$PATH"
  mkdir -p "$HOME/.local/bin"
  sudo apt update -qq
  sudo env DEBIAN_FRONTEND=noninteractive apt install -y -qq curl ffmpeg git jq tree unzip wget zsh
fi

# --- oh-my-zsh ---
# Must run before the dotfiles checkout: the installer bails out if ~/.oh-my-zsh
# already exists, and the repo tracks files under it.
if [ ! -d ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

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

# --- packages ---
if [ "$OS" == "Darwin" ]; then
  brew bundle install --file=~/Brewfile  # Brewfile comes from the checkout above

  # macOS defaults
  defaults write com.apple.WindowManager GloballyEnabled -bool true
  defaults write com.apple.WindowManager StandardHideWidgets -int 1
  defaults write com.apple.WindowManager StageManagerHideWidgets -int 1
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock showAppSuggestions -bool false
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults write com.apple.finder FXPreferredViewStyle -string clmv
  dockutil --remove all --no-restart &>/dev/null
  for app in \
    "/System/Applications/System Settings.app" \
    "/Applications/Slack.app" \
    "/Applications/Ghostty.app" \
    "/Applications/1Password.app" \
    "/Applications/Google Chrome.app" \
    "/Applications/Visual Studio Code.app" \
    "/System/Applications/Utilities/Activity Monitor.app"; do
    dockutil --add "$app" --no-restart &>/dev/null
  done
  dockutil --add ~/Downloads --view fan --display stack &>/dev/null

elif [ "$OS" == "Linux" ]; then
  DPKG_ARCH="$(dpkg --print-architecture)"          # amd64 | arm64
  case "$DPKG_ARCH" in
    amd64) RUST_ARCH=x86_64 ;;
    arm64) RUST_ARCH=aarch64 ;;
    *)
      echo "Unsupported Linux architecture: $DPKG_ARCH" >&2
      exit 1
      ;;
  esac
  # Tag of the latest GitHub release, via redirect (no API, so no rate limit).
  gh_latest() {
    curl -fsSIL -o /dev/null -w "%{url_effective}\n" "https://github.com/$1/releases/latest" | sed 's|.*/||'
  }

  # Portable binaries -> ~/.local/bin: on the ephemeral container rootfs only $HOME
  # survives reboots, so these must not go under /usr.

  # tmux: static amd64 build lives in $HOME so it survives ephemeral rootfs
  # resets. No arm64 asset is published, so use apt there.
  if ! command -v tmux &>/dev/null; then
    if [ "$DPKG_ARCH" = amd64 ]; then
      TMUX_VER=$(gh_latest mjakob-gh/build-static-tmux)
      curl -fsSL "https://github.com/mjakob-gh/build-static-tmux/releases/download/${TMUX_VER}/tmux.linux-${DPKG_ARCH}.stripped.gz" -o "$TMP_DIR/tmux.gz"
      gzip -dc "$TMP_DIR/tmux.gz" > "$TMP_DIR/tmux"
      install -m 0755 "$TMP_DIR/tmux" "$HOME/.local/bin/tmux"
    else
      sudo env DEBIAN_FRONTEND=noninteractive apt install -y -qq tmux
    fi
  fi

  # fzf (apt version is too old, no --tmux support)
  if ! command -v fzf &>/dev/null; then
    FZF_VER=$(gh_latest junegunn/fzf)
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/${FZF_VER}/fzf-${FZF_VER#v}-linux_${DPKG_ARCH}.tar.gz" -o "$TMP_DIR/fzf.tar.gz"
    tar xzf "$TMP_DIR/fzf.tar.gz" -C "$TMP_DIR"
    install -m 0755 "$TMP_DIR/fzf" "$HOME/.local/bin/fzf"
  fi

  # git-delta (musl build avoids glibc issues on older distros)
  if ! command -v delta &>/dev/null; then
    DELTA_VER=$(gh_latest dandavison/delta)
    [ "$DPKG_ARCH" = amd64 ] && DELTA_TRIPLE="${RUST_ARCH}-unknown-linux-musl" || DELTA_TRIPLE="${RUST_ARCH}-unknown-linux-gnu"
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/delta-${DELTA_VER}-${DELTA_TRIPLE}.tar.gz" -o "$TMP_DIR/delta.tar.gz"
    tar xzf "$TMP_DIR/delta.tar.gz" -C "$TMP_DIR"
    install -m 0755 "$TMP_DIR/delta-${DELTA_VER}-${DELTA_TRIPLE}/delta" "$HOME/.local/bin/delta"
  fi

  # bat
  if ! command -v bat &>/dev/null; then
    BAT_VER=$(gh_latest sharkdp/bat)
    [ "$DPKG_ARCH" = amd64 ] && BAT_TRIPLE="${RUST_ARCH}-unknown-linux-musl" || BAT_TRIPLE="${RUST_ARCH}-unknown-linux-gnu"
    curl -fsSL "https://github.com/sharkdp/bat/releases/download/${BAT_VER}/bat-${BAT_VER}-${BAT_TRIPLE}.tar.gz" -o "$TMP_DIR/bat.tar.gz"
    tar xzf "$TMP_DIR/bat.tar.gz" -C "$TMP_DIR"
    install -m 0755 "$TMP_DIR/bat-${BAT_VER}-${BAT_TRIPLE}/bat" "$HOME/.local/bin/bat"
  fi

  # zoxide (init in custom/zoxide.zsh)
  if ! command -v zoxide &>/dev/null; then
    ZOXIDE_VER=$(gh_latest ajeetdsouza/zoxide)
    ZOXIDE_VER="${ZOXIDE_VER#v}"
    curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VER}/zoxide-${ZOXIDE_VER}-${RUST_ARCH}-unknown-linux-musl.tar.gz" -o "$TMP_DIR/zoxide.tar.gz"
    tar xzf "$TMP_DIR/zoxide.tar.gz" -C "$TMP_DIR" zoxide
    install -m 0755 "$TMP_DIR/zoxide" "$HOME/.local/bin/zoxide"
  fi

  # uv and uvx
  if ! command -v uv &>/dev/null; then
    UV_VER=$(gh_latest astral-sh/uv)
    UV_TRIPLE="${RUST_ARCH}-unknown-linux-gnu"
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VER}/uv-${UV_TRIPLE}.tar.gz" -o "$TMP_DIR/uv.tar.gz"
    tar xzf "$TMP_DIR/uv.tar.gz" -C "$TMP_DIR"
    install -m 0755 "$TMP_DIR/uv-${UV_TRIPLE}/uv" "$HOME/.local/bin/uv"
    install -m 0755 "$TMP_DIR/uv-${UV_TRIPLE}/uvx" "$HOME/.local/bin/uvx"
  fi

  # gh CLI
  if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=${DPKG_ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq
    sudo env DEBIAN_FRONTEND=noninteractive apt install -y -qq gh
  fi
fi

# --- corepack ---
if [ "$OS" == "Darwin" ]; then
  npm install -g corepack
  corepack enable
fi

# --- gcloud ---
if [ -f "$HOME/google-cloud-sdk/path.bash.inc" ]; then
  # shellcheck source=/dev/null
  source "$HOME/google-cloud-sdk/path.bash.inc"
fi

if ! command -v gcloud &>/dev/null; then
  case "$OS-$ARCH" in
    Darwin-arm64)  GCLOUD_ARCHIVE="google-cloud-cli-darwin-arm.tar.gz" ;;
    Darwin-x86_64) GCLOUD_ARCHIVE="google-cloud-cli-darwin-x86_64.tar.gz" ;;
    Linux-x86_64)  GCLOUD_ARCHIVE="google-cloud-cli-linux-x86_64.tar.gz" ;;
    Linux-aarch64) GCLOUD_ARCHIVE="google-cloud-cli-linux-arm.tar.gz" ;;
  esac
  curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${GCLOUD_ARCHIVE}" -o "$TMP_DIR/$GCLOUD_ARCHIVE"
  tar -xf "$TMP_DIR/$GCLOUD_ARCHIVE" -C "$HOME"
  "$HOME/google-cloud-sdk/install.sh" --quiet
  # shellcheck source=/dev/null
  source "$HOME/google-cloud-sdk/path.bash.inc"
fi

# --- github ---
# Don't log in, and don't run `gh auth setup-git`: both are interactive or
# require a session. The tracked .gitconfig already points git at `gh` on PATH.
# Identity can only be derived from the API when a session already exists.
GITCONFIG_LOCAL="$HOME/.gitconfig-local"
if gh auth status >/dev/null 2>&1; then
  git config -f "$GITCONFIG_LOCAL" user.name "$(gh api user -q '.login')"
  git config -f "$GITCONFIG_LOCAL" user.email "$(gh api user -q '"\(.id)+\(.login)@users.noreply.github.com"')"
fi

# --- zsh plugins ---
ZSH_PLUGINS="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
[ -d "$ZSH_PLUGINS/zsh-autosuggestions" ] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_PLUGINS/zsh-autosuggestions"
[ -d "$ZSH_PLUGINS/fzf-tab" ] || git clone --depth=1 https://github.com/Aloxaf/fzf-tab.git "$ZSH_PLUGINS/fzf-tab"

# --- powerlevel10k ---
P10K="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "$P10K" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"

# --- default shell ---
# Via sudo: plain chsh prompts for an account password that containers don't have.
# $USER/$SHELL are not always set (empty env in some containers).
if [[ "${SHELL:-}" != */zsh ]]; then
  sudo chsh -s "$(command -v zsh)" "$(id -un)"
fi

if [[ -t 0 ]]; then
  rm -rf "$TMP_DIR"
  trap - EXIT
  exec zsh -l
fi
