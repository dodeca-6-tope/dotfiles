# Dotfiles
alias dot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# Git
alias g='git'

# FZF
export FZF_DEFAULT_OPTS="--layout reverse --no-separator --border none"

# PR dashboard
_p_list() {
  git rev-parse --git-dir &>/dev/null || return 0
  gh pr list --search "involves:@me" \
    --json number,url,title,author,statusCheckRollup,reviewDecision \
  | jq -r '.[] |
    def pad(n): (. + "               ")[:n];

    (.reviewDecision | if . == "APPROVED" then "\u001b[32m●"
      elif . == "CHANGES_REQUESTED" then "\u001b[31m●"
      else "\u001b[90m○" end) as $rv |
    (.statusCheckRollup | if length == 0 then "\u001b[90m□"
      elif all(.conclusion == "SUCCESS") then "\u001b[32m■"
      elif any(.conclusion == "FAILURE") then "\u001b[31m■"
      else "\u001b[33m■" end) as $ci |

    "\(.number)\t\(.url)\t\u001b[32m\(.number | tostring | pad(5))\u001b[0m \($rv) \($ci)\u001b[0m\t\u001b[36m\(.author.login | pad(15))\u001b[0m\t\(.title)"
  '
}

p() {
  _p_list | fzf --tmux 100%,100% \
    --ansi --delimiter='\t' --with-nth=3.. --tabstop=1 --no-hscroll \
    --header "⏎ view | ^d diff | ^o checkout | ^r refresh" \
    --bind 'enter:execute-silent(open {2})' \
    --bind 'ctrl-d:execute(git dp {1})' \
    --bind 'ctrl-o:become(gh pr checkout {1})' \
    --bind "ctrl-r:reload(zsh -c 'source ~/.oh-my-zsh/custom/aliases.zsh && _p_list')"
}

# Download files from Coder workspace
cdl() {
  local workspace selected
  workspace=$(coder list --output json 2>/dev/null \
    | python3 -c "import json,sys; [print(w['name']) for w in json.load(sys.stdin)]" \
    | fzf --prompt="Workspace> ")
  [[ -z "$workspace" ]] && return 0

  selected=$(ssh "coder.$workspace" "find ~ -name '.*' -prune -o -type f -print" 2>/dev/null \
    | tr -d '\r' | fzf --multi --prompt="Files> " --header="Loading..." --bind="load:change-header:")
  [[ -z "$selected" ]] && return 0

  echo "$selected" | while read -r file; do
    local dest="$HOME/Downloads/$(basename "$file")"
    rsync -az "coder.$workspace:$file" "$dest"
    [[ "$(uname)" == "Darwin" ]] && open "$dest"
  done
}
