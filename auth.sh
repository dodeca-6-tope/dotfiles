#!/usr/bin/env bash
set -euo pipefail

for cmd in git gh; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "$cmd is not installed; run setup.sh first." >&2
    exit 1
  fi
done

gh auth status >/dev/null 2>&1 || gh auth login

GITHUB_USER="$(gh api user -q '.login')"
GITHUB_ID="$(gh api user -q '.id')"
GITCONFIG_LOCAL="$HOME/.gitconfig-local"
git config -f "$GITCONFIG_LOCAL" user.name "$GITHUB_USER"
git config -f "$GITCONFIG_LOCAL" user.email "$GITHUB_ID+$GITHUB_USER@users.noreply.github.com"

echo "Authentication configured."
