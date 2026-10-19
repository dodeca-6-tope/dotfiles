# PATH must be ready before Oh My Zsh loads custom plugins such as zoxide.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$PATH"

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
DISABLE_AUTO_TITLE="true"
plugins=(
  fzf-tab
  zsh-autosuggestions
)
source $ZSH/oh-my-zsh.sh

# Secrets
[[ -f ~/.secrets ]] && source ~/.secrets

# Fall back TERM when SSH'd from Ghostty into a host without its terminfo
if [[ $TERM == xterm-ghostty ]] && ! infocmp xterm-ghostty &>/dev/null; then
  export TERM=xterm-256color
fi

# Starship
eval "$(starship init zsh)"
