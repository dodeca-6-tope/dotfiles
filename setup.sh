#!/usr/bin/env bash
set -euo pipefail

[ "$(uname)" == "Darwin" ] || { echo "macOS only"; exit 1; }

# --- brew ---
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

# --- gcloud ---
if ! command -v gcloud &>/dev/null; then
  curl -sO https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz
  tar -xf google-cloud-cli-darwin-arm.tar.gz -C "$HOME"
  "$HOME/google-cloud-sdk/install.sh" --quiet
  rm -f google-cloud-cli-darwin-arm.tar.gz
  source "$HOME/google-cloud-sdk/path.bash.inc"
fi
gcloud auth print-identity-token &>/dev/null || gcloud auth login --no-launch-browser

# --- oh-my-zsh ---
if [ ! -d ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --- github ---
gh auth status > /dev/null 2>&1 || gh auth login
gh auth setup-git

# --- dotfiles ---
if [ ! -d ~/.dotfiles ]; then
  git clone --bare https://github.com/dodeca-6-tope/dotfiles.git ~/.dotfiles
fi
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -f
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
[[ "$SHELL" == */zsh ]] || chsh -s /bin/zsh

exec zsh -l
