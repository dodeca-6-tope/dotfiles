#!/usr/bin/env bash

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

if [ -z "$branch" ]; then
  printf "%s" "$(basename "$cwd")"
  exit 0
fi

branch_icon=""

# Worktree .git is a file pointing to the main repo, not a directory
if [ -f "$cwd/.git" ]; then
  gitdir_path=$(sed 's/^gitdir: //' "$cwd/.git")
  worktree_name=$(basename "$gitdir_path")
  printf " %s · %s %s" "$worktree_name" "$branch_icon" "$branch"
else
  printf " %s · %s %s" "$(basename "$cwd")" "$branch_icon" "$branch"
fi
