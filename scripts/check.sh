#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
/bin/bash -n "$repo/setup.sh"
for file in "$repo"/zsh/*; do /bin/zsh -n "$file"; done
fixture=$(mktemp -d -t dotfiles-check)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/.config/zed"
printf 'original shell\n' > "$fixture/home/.zshrc"
printf '{"preserve":"local settings"}\n' > "$fixture/home/.config/zed/settings.json"
printf '[user]\n\tname = Fixture Owner\n\temail = fixture@example.invalid\n' > "$fixture/home/.gitconfig"
export HOME="$fixture/home"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME ZDOTDIR GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
/bin/bash "$repo/setup.sh" --config-only --dry-run > "$fixture/dry-run.log"
[[ ! -d "$HOME/.local/state/dotfiles" ]]
[[ $(cat "$HOME/.zshrc") == 'original shell' ]]
/bin/bash "$repo/setup.sh" --config-only > "$fixture/first.log"
[[ -L "$HOME/.zshrc" ]]
[[ $(git config --global user.name) == 'Fixture Owner' ]]
[[ $(git config --global --get-all include.path | wc -l | tr -d ' ') == 1 ]]
[[ $(cat "$HOME/.config/zed/settings.json") == '{"preserve":"local settings"}' ]]
[[ ! -L "$HOME/.config/zed/keymap.json" ]]
backups=$(find "$HOME/.local/state/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)
/bin/bash "$repo/setup.sh" --config-only > "$fixture/second.log"
[[ $(find "$HOME/.local/state/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | wc -l) == "$backups" ]]
[[ $(git config --global --get-all include.path | wc -l | tr -d ' ') == 1 ]]
# No private overrides in this home: neither mode should try to access the Keychain.
env -i HOME="$HOME" USER=fixture TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -c 'print -r -- NONINTERACTIVE_OK' > "$fixture/noninteractive.out" 2> "$fixture/noninteractive.err"
[[ $(cat "$fixture/noninteractive.out") == NONINTERACTIVE_OK && ! -s "$fixture/noninteractive.err" ]]
env -i HOME="$HOME" USER=fixture TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -ic 'cd /; [[ $PWD == / ]] && print -r -- INTERACTIVE_OK' > "$fixture/interactive.out" 2> "$fixture/interactive.err"
[[ $(cat "$fixture/interactive.out") == INTERACTIVE_OK ]]
if [[ -s "$fixture/interactive.err" ]]; then cat "$fixture/interactive.err" >&2; exit 1; fi
/usr/bin/script -q "$fixture/tty.log" env -i HOME="$HOME" USER="$(id -un)" TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -ic 'print -r -- TTY_OK' > "$fixture/tty.out" 2>&1
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
[[ -f "$HOME/.config/starship.toml" && ! -L "$HOME/.config/starship.toml" ]]
[[ -f "$HOME/.config/zsh/zshrc" && -L "$HOME/.zshrc" ]]
[[ -f "$HOME/.config/zed/settings.json" && ! -L "$HOME/.config/zed/settings.json" ]]
git config --global --list > "$fixture/in-place-git.out"
[[ $(git config --global --get-all include.path | wc -l | tr -d ' ') == 1 ]]
printf 'PASS: syntax, dry run, fresh config, repeat run, backups, Zed preservation, quiet shell, in-place checkout.\n'
