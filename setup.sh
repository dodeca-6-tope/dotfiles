#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"

# --- packages ---
if [ "$OS" == "Darwin" ]; then

if [ ! -f /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
for pkg in dockutil ffmpeg fzf gh imagemagick jq node tmux wget zsh tree git-delta; do
  brew install "$pkg"
done
for cask in discord docker google-chrome slack visual-studio-code vlc whatsapp; do
  brew install --cask --adopt "$cask"
done

# --- macOS defaults ---
defaults write com.apple.WindowManager GloballyEnabled -bool true
defaults write com.apple.dock autohide -bool true
dockutil --remove all --no-restart &>/dev/null
for app in \
  "/System/Applications/System Settings.app" \
  "/Applications/Slack.app" \
  "/System/Applications/Utilities/Terminal.app" \
  "/Applications/1Password.app" \
  "/Applications/Google Chrome.app" \
  "/Applications/WhatsApp.app" \
  "/Applications/Visual Studio Code.app" \
  "/System/Applications/Utilities/Activity Monitor.app"; do
  dockutil --add "$app" --no-restart &>/dev/null
done
dockutil --add ~/Downloads --view fan --display stack &>/dev/null

elif [ "$OS" == "Linux" ]; then

sudo apt update -qq
sudo apt install -y -qq bat curl ffmpeg git imagemagick jq tmux tree unzip wget zsh xclip

# fzf (apt version is too old, no --tmux support)
FZF_VER=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | jq -r '.tag_name')
curl -sL "https://github.com/junegunn/fzf/releases/download/${FZF_VER}/fzf-${FZF_VER#v}-linux_$(dpkg --print-architecture).tar.gz" | sudo tar xz -C /usr/local/bin

# gh CLI
if ! command -v gh &>/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt update -qq && sudo apt install -y -qq gh
fi

# git-delta
if ! command -v delta &>/dev/null; then
  DELTA_VER=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name')
  curl -sL "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/git-delta_${DELTA_VER}_$(dpkg --print-architecture).deb" -o /tmp/delta.deb
  sudo dpkg -i /tmp/delta.deb && rm -f /tmp/delta.deb
fi

# node
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt install -y -qq nodejs
fi

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
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --- github ---
gh auth status > /dev/null 2>&1 || gh auth login

# --- dotfiles ---
if [ ! -d ~/.dotfiles ]; then
  git clone --bare https://github.com/dodeca-6-tope/dotfiles.git ~/.dotfiles
fi
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -f
gh auth setup-git
git config --global user.name "$(gh api user -q '.login')"
git config --global user.email "$(gh api user -q '"\(.id)+\(.login)@users.noreply.github.com"')"

# --- zsh plugins ---
ZSH_PLUGINS="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
[ -d "$ZSH_PLUGINS/zsh-autosuggestions" ] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_PLUGINS/zsh-autosuggestions"
[ -d "$ZSH_PLUGINS/zsh-bat" ] || git clone --depth=1 https://github.com/fdellwing/zsh-bat.git "$ZSH_PLUGINS/zsh-bat"

# --- powerlevel10k ---
P10K="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "$P10K" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"

# --- claude code ---
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# --- default shell ---
[[ "$SHELL" == */zsh ]] || chsh -s "$(which zsh)"

exec zsh -l
