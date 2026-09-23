#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
/bin/bash -n "$repo/setup.sh"
python3 "$repo/scripts/check_credentials.py"
for file in "$repo"/zsh/*; do /bin/zsh -n "$file"; done
fixture=$(mktemp -d -t dotfiles-check)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/.config/zed"
mkdir -p "$fixture/home/projects/georgeleepatterson"
printf 'preserve me\n' > "$fixture/home/projects/georgeleepatterson/existing"
printf 'original shell\n' > "$fixture/home/.zshrc"
printf '# existing private overrides\n' > "$fixture/home/.zshrc.local"
printf '{"preserve":"local settings"}\n' > "$fixture/home/.config/zed/settings.json"
printf '[user]\n\tname = Fixture Owner\n\temail = fixture@example.invalid\n' > "$fixture/home/.gitconfig"
export HOME="$fixture/home"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME ZDOTDIR GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
/bin/bash "$repo/setup.sh" --config-only --dry-run > "$fixture/dry-run.log"
[[ ! -d "$HOME/.local/state/dotfiles" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ ! -d "$HOME/projects/ai" && ! -d "$HOME/projects/packages" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(cat "$HOME/.zshrc") == 'original shell' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
/bin/bash "$repo/setup.sh" --config-only > "$fixture/first.log"
[[ -L "$HOME/.zshrc" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(cat "$HOME/.zshrc.local") == '# existing private overrides' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(git config --global user.name) == 'Fixture Owner' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(git config --global --includes user.email) == 'fixture@example.invalid' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ -d "$HOME/projects/ai" && -d "$HOME/projects/packages" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(cat "$HOME/projects/georgeleepatterson/existing") == 'preserve me' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(git config --global --get-all include.path | wc -l | tr -d ' ') == 1 ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
# Identity supplied by another include must also win over personal defaults.
printf '[user]\n\tname = Included Owner\n\temail = included@example.invalid\n' > "$HOME/identity.gitconfig"
git config --global --unset user.name
git config --global --unset user.email
git config --global --add include.path "$HOME/identity.gitconfig"
/bin/bash "$repo/setup.sh" --config-only > "$fixture/included.log"
[[ $(git config --global --includes user.name) == 'Included Owner' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(git config --global --includes user.email) == 'included@example.invalid' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ -z $(git config --global --get user.name || true) ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(cat "$HOME/.config/zed/settings.json") == '{"preserve":"local settings"}' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ ! -L "$HOME/.config/zed/keymap.json" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
backups=$(find "$HOME/.local/state/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)
/bin/bash "$repo/setup.sh" --config-only > "$fixture/second.log"
[[ $(find "$HOME/.local/state/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | wc -l) == "$backups" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(git config --global --get-all include.path | wc -l | tr -d ' ') == 2 ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
# Non-TTY shells do not perform automatic Keychain reads.
env -i HOME="$HOME" USER=fixture TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -c 'print -r -- NONINTERACTIVE_OK' > "$fixture/noninteractive.out" 2> "$fixture/noninteractive.err"
[[ $(cat "$fixture/noninteractive.out") == NONINTERACTIVE_OK && ! -s "$fixture/noninteractive.err" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
env -i HOME="$HOME" USER=fixture TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -ic 'cd /; [[ $PWD == / ]] && print -r -- INTERACTIVE_OK' > "$fixture/interactive.out" 2> "$fixture/interactive.err"
[[ $(cat "$fixture/interactive.out") == INTERACTIVE_OK ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
if [[ -s "$fixture/interactive.err" ]]; then cat "$fixture/interactive.err" >&2; exit 1; fi
# The TTY fixture must not read the real user's Keychain. Autoload behavior is
# checked separately with synthetic entries by check_credentials.py.
/usr/bin/script -q "$fixture/tty.log" env -i HOME="$HOME" USER="$(id -un)" DOTFILES_KEYCHAIN_AUTOLOAD=0 TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -ic 'print -r -- TTY_OK' > "$fixture/tty.out" 2>&1
grep -q TTY_OK "$fixture/tty.log"
if grep -Eiq 'not found|aborted|can.t change|parse error|permission denied' "$fixture/tty.log"; then cat "$fixture/tty.log" >&2; exit 1; fi
# A checkout in .config must not turn any source into a self-referential symlink.
export HOME="$fixture/in-place"
mkdir -p "$HOME/.config"
# Copy only tracked source files, never the user's app state beside this checkout.
while IFS= read -r -d '' file; do
  mkdir -p "$HOME/.config/$(dirname "$file")"
  cp -p "$repo/$file" "$HOME/.config/$file"
done < <(git -C "$repo" ls-files -z)
/bin/bash "$HOME/.config/setup.sh" --config-only > "$fixture/in-place.log"
[[ -f "$HOME/.config/starship.toml" && ! -L "$HOME/.config/starship.toml" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ -f "$HOME/.config/zsh/zshrc" && -L "$HOME/.zshrc" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ -f "$HOME/.config/zed/settings.json" && ! -L "$HOME/.config/zed/settings.json" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
git config --global --list > "$fixture/in-place-git.out"
[[ $(git config --global --get-all include.path | wc -l | tr -d ' ') == 1 ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(git config --global user.name) == 'George Patterson' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(git config --global user.email) == 'patterson.george@gmail.com' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ -f "$HOME/.zshrc.local" && ! -L "$HOME/.zshrc.local" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
[[ $(stat -f '%Lp' "$HOME/.zshrc.local") == 600 ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
# Updating several Git fields must keep the original backup, not an intermediate edit.
export HOME="$fixture/missing-identity"
mkdir -p "$HOME"
printf '[fetch]\n\tprune = true\n' > "$HOME/.gitconfig"
cp "$HOME/.gitconfig" "$fixture/original.gitconfig"
/bin/bash "$repo/setup.sh" --config-only > "$fixture/identity.log"
cmp "$fixture/original.gitconfig" "$HOME"/.local/state/dotfiles/backups/*/.gitconfig
[[ $(git config --global user.email) == 'patterson.george@gmail.com' ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
printf 'PASS: syntax, dry run, identity defaults and preservation, project directories, repeat run, backups, Zed preservation, quiet shell, in-place checkout.\n'
