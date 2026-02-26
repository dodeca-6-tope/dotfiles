# Dotfiles
alias dot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# Git
alias g='git'

# Clipboard
if [[ "$(uname)" == "Darwin" ]]; then
  alias clip='pbcopy'
else
  alias clip='xclip -selection clipboard'
fi

# FZF
export FZF_DEFAULT_OPTS="--layout reverse --no-separator"

_fzf_tmux_fit() {
  local width=${1:-80%} padding=${2:-3} input=$(cat)
  [[ -z "$input" ]] && return 1
  local height=$(( $(echo "$input" | wc -l | tr -d ' ') + padding ))
  echo "$input" | fzf --tmux "center,${width},${height}" "${@:3}"
}

# PR dashboard
p() {
  gh pr list --search "involves:@me" \
    --json number,title,author,statusCheckRollup,reviewDecision \
  | jq -r '.[] |
    def icon(ok; bad): if . == ok then "\u001b[32m" elif . == bad then "\u001b[31m" else "\u001b[90m" end;
    def pad(n): (. + "               ")[:n];

    (.reviewDecision | icon("APPROVED"; "CHANGES_REQUESTED")) as $rv |
    (if (.statusCheckRollup | length) == 0 then "\u001b[90m"
     elif (.statusCheckRollup | any(.conclusion == "FAILURE")) then "\u001b[31m"
     elif (.statusCheckRollup | all(.conclusion == "SUCCESS")) then "\u001b[32m"
     else "\u001b[33m" end) as $ci |

    "\u001b[32m\(.number | tostring | pad(5))\u001b[0m \($rv)● \($ci)■\u001b[0m\t\u001b[36m\(.author.login | pad(15))\u001b[0m\t\(.title)"
  ' \
  | _fzf_tmux_fit 80% 3 \
    --ansi --delimiter='\t' --tabstop=1 --no-hscroll \
    --header "⏎ view | ^d diff | ^o checkout | ^r refresh" \
    --bind "enter:execute(gh pr view --web {1})" \
    --bind "ctrl-d:execute(git dp {1})+abort" \
    --bind "ctrl-o:execute(gh pr checkout {1})+abort" \
    --bind "ctrl-r:reload(zsh -c 'source ~/.oh-my-zsh/custom/aliases.zsh && p')" \
  || echo "No PRs found."
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
