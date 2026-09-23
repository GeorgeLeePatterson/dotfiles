#!/bin/bash
# macOS ships Bash 3.2; no extra runtime is needed to bootstrap this repository.
set -euo pipefail
umask 077
repo=$(cd "$(dirname "$0")" && pwd -P)
config_only=0
dry_run=0
for arg in "$@"; do
  case "$arg" in
    --config-only) config_only=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help)
      printf 'Usage: %s [--config-only] [--dry-run]\n' "$0"
      printf 'Install missing CLI tools, Node 24, and link personal configuration.\n'
      printf 'Existing files are backed up; packages are never removed or upgraded.\n'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
[[ $(uname -s) == Darwin ]] || { printf 'This setup currently supports macOS only.\n' >&2; exit 1; }
[[ $EUID -ne 0 ]] || { printf 'Run as your normal user, not with sudo.\n' >&2; exit 1; }

backup=''
backup_file() {
  local target=$1
  if [[ -z "$backup" ]]; then
    mkdir -p "$HOME/.local/state/dotfiles/backups"
    backup=$(mktemp -d "$HOME/.local/state/dotfiles/backups/$(date +%Y%m%d-%H%M%S).XXXXXX")
    printf 'Backup: %s\n' "$backup"
  fi
  local relative=${target#"$HOME/"}
  mkdir -p "$backup/$(dirname "$relative")"
  cp -Pp "$target" "$backup/$relative"
}
link_file() {
  local source="$repo/$1" target="$2" target_parent
  [[ -f "$source" ]] || { printf 'Missing repository file: %s\n' "$source" >&2; exit 1; }
  # Cloning directly into ~/.config is supported; never replace a source with itself.
  if [[ -e "$target" && "$source" -ef "$target" ]]; then return; fi
  if [[ -L "$target" && $(readlink "$target") == "$source" ]]; then return; fi
  if [[ -d "$target" ]]; then printf 'Refusing to replace a directory: %s\n' "$target" >&2; exit 1; fi
  if (( dry_run )); then printf 'Link %s -> %s\n' "$target" "$source"; return; fi
  if [[ -e "$target" || -L "$target" ]]; then backup_file "$target"; fi
  target_parent=$(dirname "$target")
  mkdir -p "$target_parent"
  # Stage beside the destination, then rename; a failed link cannot remove the old file.
  local stage
  stage=$(mktemp -d "$target_parent/.dotfiles-link.XXXXXX")
  ln -s "$source" "$stage/link"
  mv -fh "$stage/link" "$target"
  rmdir "$stage"
  printf 'Linked %s\n' "$target"
}

if (( ! config_only )); then
  if (( dry_run )); then
    printf 'Install Homebrew if missing, then missing packages from %s/Brewfile.\n' "$repo"
    printf 'Install Node 24 through fnm if no default is configured.\n'
  else
    brew_bin=''
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$candidate" ]]; then brew_bin=$candidate; break; fi
    done
    if [[ -z "$brew_bin" ]]; then
      printf 'Installing Homebrew from its official installer; it may request your administrator password.\n'
      installer=$(mktemp -t dotfiles-homebrew)
      trap 'rm -f "$installer"' EXIT
      curl --fail --location --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
      /bin/bash "$installer"
      rm -f "$installer"
      trap - EXIT
      if [[ -x /opt/homebrew/bin/brew ]]; then brew_bin=/opt/homebrew/bin/brew; else brew_bin=/usr/local/bin/brew; fi
    fi
    eval "$("$brew_bin" shellenv)"
    HOMEBREW_NO_AUTO_UPDATE=1 "$brew_bin" bundle install --file="$repo/Brewfile" --no-upgrade
    # fnm retains a pre-existing default. The new-machine default matches this setup.
    if ! fnm default >/dev/null 2>&1; then
      fnm install 24
      fnm default 24
    fi
  fi
fi

link_file zsh/zshenv "$HOME/.zshenv"
link_file zsh/zprofile "$HOME/.zprofile"
link_file zsh/zshrc "$HOME/.zshrc"
# These two files are sourced relative to ~/.config, even when the repo lives elsewhere.
link_file zsh/aliases.zsh "$HOME/.config/zsh/aliases.zsh"
link_file zsh/keychain.zsh "$HOME/.config/zsh/keychain.zsh"
for relative in starship.toml ghostty/config bat/config fd/ignore atuin/config.toml micro/settings.json micro/bindings.json git/ignore; do
  link_file "$relative" "$HOME/.config/$relative"
done

# Zed can save tokens in settings. Copy defaults once; never symlink its writable files.
for name in settings.json keymap.json; do
  target="$HOME/.config/zed/$name"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    if (( dry_run )); then printf 'Copy Zed default to %s\n' "$target";
    else mkdir -p "$(dirname "$target")"; cp -p "$repo/defaults/zed/$name" "$target"; fi
  fi
done

# Add portable Git preferences without replacing identity, auth helpers or includes.
git_include="$repo/git/preferences.gitconfig"
if ! git config --global --get-all include.path 2>/dev/null | grep -Fqx -- "$git_include"; then
  if (( dry_run )); then
    printf 'Include %s in ~/.gitconfig (preserving existing settings).\n' "$git_include"
  else
    if [[ -e "$HOME/.gitconfig" || -L "$HOME/.gitconfig" ]]; then backup_file "$HOME/.gitconfig"; fi
    git config --global --add include.path "$git_include"
  fi
fi
if (( ! dry_run )); then
  printf '\nReady. Open a new terminal to use the setup.\n'
  printf 'Machine-only settings and secrets belong in ~/.zshrc.local or ~/.zshenv.local.\n'
  if [[ -z $(git config --global user.name || true) || -z $(git config --global user.email || true) ]]; then
    printf 'Set your Git identity with git config --global user.name and user.email.\n'
  fi
fi
