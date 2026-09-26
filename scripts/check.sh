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
# The disposable-home checks never access the real Keychain. Synthetic startup
# credential loading is exercised separately by check_credentials.py.
export DOTFILES_KEYCHAIN_AUTOLOAD=0
env -i DOTFILES_KEYCHAIN_AUTOLOAD=0 HOME="$HOME" USER=fixture TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -c 'print -r -- NONINTERACTIVE_OK' > "$fixture/noninteractive.out" 2> "$fixture/noninteractive.err"
[[ $(cat "$fixture/noninteractive.out") == NONINTERACTIVE_OK && ! -s "$fixture/noninteractive.err" ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
env -i DOTFILES_KEYCHAIN_AUTOLOAD=0 HOME="$HOME" USER=fixture TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -ic 'cd /; [[ $PWD == / ]] && print -r -- INTERACTIVE_OK' > "$fixture/interactive.out" 2> "$fixture/interactive.err"
[[ $(cat "$fixture/interactive.out") == INTERACTIVE_OK ]] || { printf "FAIL: line %s\n" "$LINENO" >&2; exit 1; }
if [[ -s "$fixture/interactive.err" ]]; then cat "$fixture/interactive.err" >&2; exit 1; fi
# Simulate a terminal app still passing an obsolete fnm environment to a new shell.
env -i HOME="$HOME" USER=fixture DOTFILES_KEYCHAIN_AUTOLOAD=0 FNM_DIR="$HOME/.local/share/fnm" FNM_MULTISHELL_PATH="$HOME/.local/state/fnm_multishells/old" FNM_NODE_DIST_MIRROR=https://example.invalid PATH="$HOME/.local/state/fnm_multishells/old/bin:$HOME/.local/share/fnm/node-versions/v24/installation/bin:$fixture/keep-fnm-tools/bin:/usr/bin:/bin:/usr/sbin:/sbin" EXPECTED_KEEP="$fixture/keep-fnm-tools/bin" /bin/zsh -c '
  [[ -z ${FNM_DIR+x} && -z ${FNM_MULTISHELL_PATH+x} && -z ${FNM_NODE_DIST_MIRROR+x} ]] || exit 1
  [[ $PATH != *fnm_multishells* && $PATH != *"/.local/share/fnm/"* ]] || exit 1
  [[ ":$PATH:" == *":$EXPECTED_KEEP:"* ]] || exit 1
  print -r -- FNM_RETIRED
' > "$fixture/fnm.out" 2> "$fixture/fnm.err"
[[ $(cat "$fixture/fnm.out") == FNM_RETIRED && ! -s "$fixture/fnm.err" ]] || { printf 'FAIL: inherited fnm environment\n' >&2; exit 1; }
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
# Exercise the real package-install flow with a fake Homebrew/NVM in a disposable
# checkout. Only external executable discovery is redirected; no packages install.
mkdir -p "$fixture/fake-brew" "$fixture/in-place/.nvm/alias"
cat > "$fixture/fake-brew/brew" <<'BREW'
#!/bin/bash
case "$1" in
  shellenv) exit 0 ;;
  bundle) printf '%s %s\n' "${4##*/}" "$(umask)" >> "$DOTFILES_TEST_BREW_LOG" ;;
  *) exit 93 ;;
esac
BREW
chmod 700 "$fixture/fake-brew/brew"
printf '24\n' > "$fixture/in-place/.nvm/alias/default"
printf 'nvm() { printf "v24.0.0\\n"; }\n' > "$fixture/in-place/.nvm/nvm.sh"
python3 - "$fixture/in-place/.config/setup.sh" "$fixture/fake-brew/brew" <<'PYTEST'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text().replace('/opt/homebrew/bin/brew', sys.argv[2]).replace('/usr/local/bin/brew', sys.argv[2]))
PYTEST
env HOME="$fixture/in-place" DOTFILES_TEST_BREW_LOG="$fixture/brew-modes" /bin/bash "$fixture/in-place/.config/setup.sh" --apps --dev > "$fixture/packages.log"
[[ $(wc -l < "$fixture/brew-modes" | tr -d ' ') == 3 ]] || { printf 'FAIL: expected three package profiles\n' >&2; exit 1; }
[[ $(awk '$NF != "0022" {print}' "$fixture/brew-modes") == '' ]] || { printf 'FAIL: package install inherited private umask\n' >&2; exit 1; }
[[ $(stat -f '%Lp' "$fixture/in-place/.zshrc.local") == 600 ]] || { printf 'FAIL: private config permissions changed\n' >&2; exit 1; }
printf 'PASS: syntax, dry run, identity defaults and preservation, project directories, repeat run, backups, Zed preservation, quiet shell, in-place checkout, package/private permission separation.\n'
