# Download files from a Coder workspace to ~/Downloads and open them.
# Usage: coder-dl
#   1. Pick a workspace
#   2. Pick files (multi-select with Tab)
#   3. Files are downloaded and opened
coder-dl() {
  local workspace selected file dest

  # Pick workspace
  workspace=$(
    coder list --output json 2>/dev/null \
      | python3 -c "import json,sys; [print(w['name']) for w in json.load(sys.stdin)]" \
      | fzf --prompt="Workspace> "
  )
  [[ -z "$workspace" ]] && return 0

  # Pick files
  selected=$(
    ssh "coder.$workspace" "find ~ -name '.*' -prune -o -type f -print" 2>/dev/null \
      | tr -d '\r' \
      | fzf --multi --prompt="Files> " --header="Loading..." --bind="load:change-header:"
  )
  [[ -z "$selected" ]] && return 0

  # Download and open
  echo "$selected" | while read -r file; do
    dest="$HOME/Downloads/$(basename "$file")"
    rsync -az "coder.$workspace:$file" "$dest"
    [[ "$(uname)" == "Darwin" ]] && open "$dest"
  done
}
