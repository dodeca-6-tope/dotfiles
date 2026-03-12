# Let ~/.gitconfig-local identity take precedence over Coder's env vars
unset GIT_AUTHOR_NAME GIT_COMMITTER_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_EMAIL

# Download a file from a Coder workspace to ~/Downloads and open it.
# Usage: coder-scp <workspace> <remote-path> [local-dest]
# Example: coder-scp black-magic /tmp/surfer_comparison.zip
coder-scp() {
  local workspace="$1" file="$2"
  local user; user=$(coder whoami --output json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['username'])")
  local dest="${3:-$HOME/Downloads/$(basename "$file")}"
  scp "main.$workspace.$user.coder:$file" "$dest"
  [[ "$(uname)" == "Darwin" ]] && open "$dest"
}

_coder-scp() {
  if (( CURRENT == 2 )); then
    local workspaces; workspaces=($(coder list --output json 2>/dev/null | python3 -c "import json,sys; [print(w['name']) for w in json.load(sys.stdin)]"))
    _describe 'workspace' workspaces
  fi
}
compdef _coder-scp coder-scp
