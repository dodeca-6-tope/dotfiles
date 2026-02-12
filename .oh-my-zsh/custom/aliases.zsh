# Dotfiles
alias dot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# Git
alias g='git'

# FZF
export FZF_DEFAULT_OPTS="--tmux 90%,70% --layout reverse --no-separator --no-scrollbar --color 'label:blue'"

# PR dashboard
_p_fetch() {
  gh pr list --search "involves:@me" --json number,title,author,statusCheckRollup,reviewDecision | jq -r '.[] |
    (.reviewDecision | if . == "APPROVED" then "\u001b[32m●"
      elif . == "CHANGES_REQUESTED" then "\u001b[31m●"
      else "\u001b[90m○" end) as $rv |
    (.statusCheckRollup | if length == 0 then "\u001b[90m□"
      elif all(.conclusion == "SUCCESS") then "\u001b[32m■"
      elif any(.conclusion == "FAILURE") then "\u001b[31m■"
      else "\u001b[33m■" end) as $ci |
    "\u001b[32m\(.number | tostring | (. + "     ")[:5])\u001b[0m \($rv) \($ci)\u001b[0m \u001b[36m\(.author.login | (. + "               ")[:15])\u001b[0m \(.title)"
  '
}

_p_preview() {
  local pr=$1 tmp=$(mktemp)
  gh pr view "$pr" --json body,reviewDecision,statusCheckRollup,additions,deletions > "$tmp"

  local adds=$(jq -r '.additions' "$tmp")
  local dels=$(jq -r '.deletions' "$tmp")
  local review=$(jq -r '.reviewDecision // "PENDING"' "$tmp")
  local rv
  case "$review" in
    APPROVED)           rv="\033[32m● Approved\033[0m" ;;
    CHANGES_REQUESTED)  rv="\033[31m● Changes requested\033[0m" ;;
    *)                  rv="○ Pending" ;;
  esac
  echo -e "${rv}  │  \033[32m+${adds} \033[31m-${dels}\033[0m"

  local fail_details="{}" run_urls run_id jobs_json
  run_urls=$(jq -r '[.statusCheckRollup[] | select(.conclusion == "FAILURE") | .detailsUrl] | unique[]' "$tmp")
  for url in ${(f)run_urls}; do
    [[ -z "$url" ]] && continue
    run_id=$(echo "$url" | sed -n 's|.*/runs/\([0-9]*\)/.*|\1|p')
    [[ -z "$run_id" ]] && continue
    jobs_json=$(gh api "repos/{owner}/{repo}/actions/runs/$run_id/jobs" 2>/dev/null)
    [[ -n "$jobs_json" ]] && fail_details=$(echo "$jobs_json" | jq --argjson existing "$fail_details" '[.jobs[] | select(.conclusion == "failure") | {(.name): [.steps[] | select(.conclusion == "failure") | .name]}] | add // {} | $existing + .')
  done

  echo ""
  jq -r --argjson fails "$fail_details" '.statusCheckRollup | group_by(.name) | .[] |
    (if any(.conclusion == "FAILURE") then "FAILURE"
      elif all(.conclusion == "SUCCESS") then "SUCCESS"
      elif any(.conclusion == null or .conclusion == "") then "PENDING"
      else .[0].conclusion end) as $c |
    (.[0].name) as $name |
    if $c == "SUCCESS" then "\u001b[32m✓\u001b[0m \($name)"
    elif $c == "FAILURE" then "\u001b[31m✗\u001b[0m \($name)" + ($fails[$name] // [] | map("\n  ↳ \(.)") | join(""))
    elif $c == "PENDING" then "\u001b[33m●\u001b[0m \($name)"
    else "- \($name)" end' "$tmp"

  local body
  body=$(jq -r 'if .body != "" and .body != null then .body else empty end' "$tmp")
  if [[ -n "$body" ]]; then
    echo ""
    echo "$body"
  fi
  rm -f "$tmp"
}

p() {
  _p_fetch | fzf --ansi --header "⏎ view | ^d diff | ^o checkout | ^r refresh" \
    --preview "zsh -c 'source ~/.oh-my-zsh/custom/aliases.zsh && _p_preview {1}'" \
    --preview-window bottom:60%:wrap \
    --bind "enter:execute(gh pr view --web {1})" \
    --bind "ctrl-d:execute(git dp {1})+abort" \
    --bind "ctrl-o:execute(gh pr checkout {1})+abort" \
    --bind "ctrl-r:reload(zsh -c 'source ~/.oh-my-zsh/custom/aliases.zsh && _p_fetch')"
}
