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
  sudo env DEBIAN_FRONTEND=noninteractive apt install -y -qq curl git jq tree unzip wget zsh
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

elif [ "$OS" == "Linux" ]; then
  DPKG_ARCH="$(dpkg --print-architecture)"  # amd64 | arm64
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

  # musl builds tolerate older glibc, but upstreams only publish them for amd64.
  libc_triple() {
    if [ "$DPKG_ARCH" = amd64 ]; then
      echo "${RUST_ARCH}-unknown-linux-musl"
    else
      echo "${RUST_ARCH}-unknown-linux-gnu"
    fi
  }

  # Install release binaries under $HOME, since apt either has no package for
  # them or ships one too old. $2 is the path prefix inside the tarball, empty
  # when the binaries sit at its root.
  install_release_tar() {
    local url="$1" prefix="$2" bin
    shift 2
    curl -fsSL "$url" -o "$TMP_DIR/release.tar.gz"
    tar xzf "$TMP_DIR/release.tar.gz" -C "$TMP_DIR"
    for bin in "$@"; do
      install -m 0755 "$TMP_DIR/$prefix$bin" "$HOME/.local/bin/$bin"
    done
  }

  if ! command -v tmux &>/dev/null; then
    # The static build has no arm64 asset, so fall back to apt there.
    if [ "$DPKG_ARCH" = amd64 ]; then
      TMUX_VER=$(gh_latest mjakob-gh/build-static-tmux)
      curl -fsSL "https://github.com/mjakob-gh/build-static-tmux/releases/download/${TMUX_VER}/tmux.linux-${DPKG_ARCH}.stripped.gz" -o "$TMP_DIR/tmux.gz"
      gzip -dc "$TMP_DIR/tmux.gz" > "$TMP_DIR/tmux"
      install -m 0755 "$TMP_DIR/tmux" "$HOME/.local/bin/tmux"
    else
      sudo env DEBIAN_FRONTEND=noninteractive apt install -y -qq tmux
    fi
  fi

  if ! command -v fzf &>/dev/null; then
    FZF_VER=$(gh_latest junegunn/fzf)
    install_release_tar "https://github.com/junegunn/fzf/releases/download/${FZF_VER}/fzf-${FZF_VER#v}-linux_${DPKG_ARCH}.tar.gz" "" fzf
  fi

  if ! command -v delta &>/dev/null; then
    DELTA_VER=$(gh_latest dandavison/delta)
    DELTA_TRIPLE="$(libc_triple)"
    install_release_tar "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/delta-${DELTA_VER}-${DELTA_TRIPLE}.tar.gz" "delta-${DELTA_VER}-${DELTA_TRIPLE}/" delta
  fi

  if ! command -v bat &>/dev/null; then
    BAT_VER=$(gh_latest sharkdp/bat)
    BAT_TRIPLE="$(libc_triple)"
    install_release_tar "https://github.com/sharkdp/bat/releases/download/${BAT_VER}/bat-${BAT_VER}-${BAT_TRIPLE}.tar.gz" "bat-${BAT_VER}-${BAT_TRIPLE}/" bat
  fi

  if ! command -v zoxide &>/dev/null; then
    ZOXIDE_VER="$(gh_latest ajeetdsouza/zoxide)"
    install_release_tar "https://github.com/ajeetdsouza/zoxide/releases/download/${ZOXIDE_VER}/zoxide-${ZOXIDE_VER#v}-${RUST_ARCH}-unknown-linux-musl.tar.gz" "" zoxide
  fi

  if ! command -v uv &>/dev/null; then
    UV_VER=$(gh_latest astral-sh/uv)
    UV_TRIPLE="${RUST_ARCH}-unknown-linux-gnu"
    install_release_tar "https://github.com/astral-sh/uv/releases/download/${UV_VER}/uv-${UV_TRIPLE}.tar.gz" "uv-${UV_TRIPLE}/" uv uvx
  fi

  if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=${DPKG_ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq
    sudo env DEBIAN_FRONTEND=noninteractive apt install -y -qq gh
  fi
fi

# --- macOS preferences ---
if [ "$OS" == "Darwin" ]; then
  defaults write com.apple.WindowManager GloballyEnabled -bool true
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock showAppSuggestions -bool false
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string clmv
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  # `defaults` persists this value but doesn't apply it to the current session.
  # This is the same private framework call used by the Mouse settings pane.
  /usr/bin/python3 - <<'PY'
from ctypes import CDLL, c_bool

framework = CDLL(
    "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport"
)
set_direction = framework.setSwipeScrollDirection
set_direction.argtypes = [c_bool]
set_direction.restype = None
set_direction(False)
PY

  dockutil --remove all --no-restart &>/dev/null
  for app in \
    "/System/Applications/System Settings.app" \
    "/Applications/Ghostty.app" \
    "/Applications/Google Chrome.app" \
    "/Applications/Visual Studio Code.app" \
    "/System/Applications/Utilities/Activity Monitor.app"; do
    dockutil --add "$app" --no-restart &>/dev/null
  done
  dockutil --add ~/Downloads --view fan --display stack &>/dev/null
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

# --- next steps ---
echo
echo "Setup complete."
if ! gh auth status >/dev/null 2>&1; then
  echo "To authenticate GitHub, run:"
  echo "  bash ~/auth.sh"
fi

# exec replaces this shell, so the EXIT trap never runs; clean up first.
if [[ -t 0 ]]; then
  rm -rf "$TMP_DIR"
  trap - EXIT
  exec zsh -l
fi
