# Dotfiles

Setup script and config files managed with a [bare repo](https://www.atlassian.com/git/tutorials/dotfiles).

## Supported systems

- macOS: Homebrew installs CLI tools and desktop apps; setup also applies macOS preferences.
- Debian/Ubuntu Linux: `apt` and `sudo` are required; amd64 and arm64 are supported by the installer. CLI tools are installed without macOS apps or preferences.
- The bootstrap command requires Bash, curl, and internet access. Use a terminal font with Powerline/Nerd Font glyphs for the Git branch icon.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dodeca-6-tope/dotfiles/main/setup.sh)
```

The installer checks out `origin/main` and resets tracked dotfiles to that version. Commit and push changes before using it on another machine; rerunning it discards local changes to tracked files.

## Verify

Open a new terminal, enter a Git repository, and run:

```bash
zsh -lic 'for tool in starship fzf delta zoxide gh tmux; do command -v "$tool" || exit 1; done; starship timings'
```

This checks tool discovery and renders the prompt modules. It does not replace testing the complete installer in a disposable machine: test a fresh macOS user or VM and fresh Debian/Ubuntu environments on each supported architecture. There is currently no automated clean-install CI.

## Authenticate

Authentication is intentionally separate from installation:

```bash
bash ~/auth.sh
```

This signs into GitHub, then writes the active GitHub account's commit
identity to `~/.gitconfig-local`.

## Usage

Use the `dot` alias as a drop-in replacement for `git` to manage dotfiles.
