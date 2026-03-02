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
