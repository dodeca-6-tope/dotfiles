# Dotfiles

Setup script and config files managed with a [bare repo](https://www.atlassian.com/git/tutorials/dotfiles).

Supports macOS and Debian/Ubuntu Linux (amd64 and arm64).

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dodeca-6-tope/dotfiles/main/setup.sh)
```

Rerunning setup replaces tracked dotfiles with the version from `origin/main`.

## Authenticate

Authentication is intentionally separate from installation:

```bash
bash ~/auth.sh
```

This signs into GitHub, then writes the active GitHub account's commit
identity to `~/.gitconfig-local`.

## Usage

Use the `dot` alias as a drop-in replacement for `git` to manage dotfiles.
