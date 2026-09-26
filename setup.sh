#!/bin/bash
# macOS ships Bash 3.2; no extra runtime is needed to bootstrap this repository.
set -euo pipefail
umask 077
repo=$(cd "$(dirname "$0")" && pwd -P)
config_only=0
dry_run=0
github_ssh=0
dev=0
apps=0
for arg in "$@"; do
  case "$arg" in
    --config-only) config_only=1 ;;
    --dry-run) dry_run=1 ;;
    --github-ssh) github_ssh=1 ;;
    --dev) dev=1 ;;
    --apps) apps=1 ;;
    -h|--help)
      printf 'Usage: %s [--config-only] [--dry-run] [--github-ssh] [--dev] [--apps]\n' "$0"
      printf 'Install missing CLI tools, Node 24, and link personal configuration.\n'
      printf 'Existing files are backed up; packages are never removed or upgraded.\n'
      printf 'Add --github-ssh for GitHub browser sign-in and SSH key enrollment.\n'
      printf 'Docker Desktop is baseline. Add --dev for extra CLI tools or --apps for desktop apps.\n'
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
  # Several settings may update the same file; retain its original contents.
  if [[ ! -e "$backup/$relative" && ! -L "$backup/$relative" ]]; then
    cp -Pp "$target" "$backup/$relative"
  fi
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
    printf 'Install NVM if missing; install Node 24 if no NVM default is configured.\n'
    (( ! dev )) || printf 'Install missing packages from Brewfile.dev (tmux, lazygit, glow).\n'
    (( ! apps )) || printf 'Install missing applications from Brewfile.apps; preserve manual installs.\n'
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
    for profile in dev apps; do
      if [[ $profile == dev && $dev == 1 || $profile == apps && $apps == 1 ]]; then
        HOMEBREW_NO_AUTO_UPDATE=1 "$brew_bin" bundle install --file="$repo/Brewfile.$profile" --no-upgrade
      fi
    done
    # Keep existing NVM installations and defaults. Pin the bootstrap release;
    # let our tracked shell files handle initialization, not NVM's installer.
    (
      export NVM_DIR="$HOME/.nvm"
      if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        mkdir -p "$NVM_DIR"
        installer=$(mktemp -t dotfiles-nvm)
        trap 'rm -f "$installer"' EXIT
        curl --fail --location --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh -o "$installer"
        PROFILE=/dev/null /bin/bash "$installer"
      fi
      set +u # NVM supports ordinary shells, not Bash's nounset mode.
      source "$NVM_DIR/nvm.sh" --no-use
      if [[ -s "$NVM_DIR/alias/default" ]]; then
        if [[ $(nvm version default) == N/A ]]; then nvm install default; fi
      else
        nvm install 24
        nvm alias default 24
      fi
    )
  fi
fi

for name in georgeleepatterson ai packages; do
  if (( dry_run )); then printf 'Ensure directory %s/projects/%s\n' "$HOME" "$name";
  else mkdir -p "$HOME/projects/$name"; fi
done

link_file zsh/zshenv "$HOME/.zshenv"
link_file zsh/zprofile "$HOME/.zprofile"
link_file zsh/zshrc "$HOME/.zshrc"
# These two files are sourced relative to ~/.config, even when the repo lives elsewhere.
link_file zsh/aliases.zsh "$HOME/.config/zsh/aliases.zsh"
link_file zsh/keychain.zsh "$HOME/.config/zsh/keychain.zsh"
link_file scripts/credentials.py "$HOME/.local/bin/dotfiles-credentials"
link_file scripts/doctor.py "$HOME/.local/bin/dotfiles-doctor"
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

# A private copy, not a symlink: anything added later stays outside this repo.
if [[ ! -e "$HOME/.zshrc.local" && ! -L "$HOME/.zshrc.local" ]]; then
  if (( dry_run )); then printf 'Create private ~/.zshrc.local from the secret-free template.\n';
  else cp "$repo/defaults/zshrc.local" "$HOME/.zshrc.local"; chmod 600 "$HOME/.zshrc.local"; fi
fi

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
# Seed personal identity on a fresh machine, while respecting existing global
# settings (including identities supplied by another Git config include).
for key in user.name user.email; do
  if [[ -z $(git config --global --includes --get "$key" || true) ]]; then
    if (( dry_run )); then
      printf 'Set missing Git %s from defaults/gitconfig.\n' "$key"
    else
      if [[ -e "$HOME/.gitconfig" || -L "$HOME/.gitconfig" ]]; then backup_file "$HOME/.gitconfig"; fi
      git config --global "$key" "$(git config --file "$repo/defaults/gitconfig" --get "$key")"
    fi
  fi
done
if (( github_ssh )); then
  if (( dry_run )); then
    printf 'Run GitHub CLI browser sign-in with SSH key creation/upload prompts.\n'
  else
    [[ -t 0 && -t 1 ]] || { printf 'GitHub sign-in needs a terminal. Re-run setup with --config-only --github-ssh in your terminal.\n' >&2; exit 1; }
    printf '\nGitHub will offer to generate/upload this Mac\047s SSH key. Choose a passphrase when prompted.\n'
    # Old exported tokens otherwise bypass the normal browser/keychain login flow.
    env -u GH_TOKEN -u GITHUB_TOKEN gh auth login --hostname github.com --git-protocol ssh --web
    printf '\nTo save your SSH passphrase in macOS Keychain, use Apple\047s ssh-add:\n'
    printf '  /usr/bin/ssh-add --apple-use-keychain <private-key-path-shown-above>\n'
    printf 'Existing HTTPS clones keep their current remote URL. See README for switching a checkout to SSH.\n'
  fi
fi
if (( ! dry_run )); then
  printf '\nConfiguration applied. Open a new terminal, then run dotfiles-doctor.\n'
  printf 'Docker Desktop may need its first-launch setup. Project commands own containers and databases.\n'
  printf 'Use dotfiles-doctor --apps --dev or --project <path> to check those prerequisites too.\n'
  printf 'Machine-only preferences belong in private shell overrides; credentials belong in Keychain.\n'
fi
