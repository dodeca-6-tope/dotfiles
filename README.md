# Dotfiles

Setup script and config files managed with a [bare repo](https://www.atlassian.com/git/tutorials/dotfiles).

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dodeca-6-tope/dotfiles/main/setup.sh)
```

Authentication is intentionally separate:

```bash
gh auth login
gcloud auth login
```

Re-run the installer after GitHub login to populate `~/.gitconfig-local`.

## Usage

Use the `dot` alias as a drop-in replacement for `git` to manage dotfiles.
