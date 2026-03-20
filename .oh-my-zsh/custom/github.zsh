# Open PR or repo on GitHub
o() {
  gh pr view --web 2>/dev/null || gh browse
}
