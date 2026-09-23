# My Mac setup

A small, personal macOS setup: one Brewfile, one script, plain Zsh files. No Dotter,
submodules, plugin manager, generated shell bundle, or machine state in Git.

## New Mac

Install Apple's command-line tools if Git is not available (`xcode-select --install`),
then:

```sh
git clone https://github.com/GeorgeLeePatterson/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

Cloning outside `~/.config` works even when apps already created that directory.
Cloning straight into an empty `~/.config` also works. Keep the checkout: most
configuration files link back to it.

The script:

1. Installs Homebrew from its official installer if necessary. It may ask for your
   Mac administrator password; run the script as your normal user, not with sudo.
2. Installs missing packages from `Brewfile`, without upgrading or removing others.
3. Installs NVM from its official release if missing. New machines get Node 24;
   existing NVM installations, versions and defaults stay.
4. Links `.zshenv`, `.zprofile`, `.zshrc`, the prompt, Ghostty and small tool configs.
5. Includes shared Git preferences and fills in missing global identity fields from
   `defaults/gitconfig` (George Patterson / patterson.george@gmail.com). Existing
   identities, including those in Git includes, and sign-ins are preserved.
6. Copies sanitized Zed settings and keybindings only if those files do not exist.
7. Creates `~/projects/georgeleepatterson`, `~/projects/ai`, and `~/projects/packages`.
   Existing directories and their contents stay in place.
8. Creates a private `~/.zshrc.local` from a secret-free template if missing. This
   file is copied with owner-only permissions; it is never linked back to Git.

Open a new terminal afterward. Use Ghostty for the current dark/light themes and
JetBrainsMono Nerd Font. Install Ghostty, Brave, Slack, Claude and Codex separately;
this repo is the terminal setup, not an application/account installer.

## What is included

- **Shell:** autosuggestions, syntax highlighting, fuzzy tab completion, Starship.
- **Navigation/history:** zoxide (`cd` + listing in a terminal), Atuin, fzf, broot,
  `j` for directory search, `ls`/`la`/`li`/`ll` using eza.
- **Daily CLI:** Git, GitHub CLI, AWS CLI, delta, Git LFS, jq, ripgrep, fd, bat, tree,
  btop, Micro and just.
- **Development:** NVM/Node 24, pnpm and uv. Node works in terminal and SSH/tool
  shells. Use `nvm use` in projects with `.nvmrc`; `nvm alias default 24` changes
  the default. Opening a subshell preserves a version selected with `nvm use`.
  Projects choose their other runtimes/tools.
- **Editor defaults:** Ghostty and Zed. Existing Zed settings are preserved, including
  any local integrations. The defaults omit account/MCP secrets and are copied rather
  than linked, so credentials Zed saves cannot enter this repo through a symlink.

`gh auth login`, AWS sign-in, native-agent sign-ins and optional Atuin
sync are per-machine setup. Passwords, tokens, SSH keys, shell history and agent
histories are never copied by this script. Git LFS is installed; use `git lfs install`
in a repo that needs its hooks.

## Re-run and customize

```sh
./setup.sh --dry-run        # preview; changes nothing
./setup.sh --config-only    # apply configs without installing software
./setup.sh                 # install anything missing, keep existing packages
```

Changed destination files are backed up under
`~/.local/state/dotfiles/backups/<timestamp>/` before replacement. Already-correct
links are left alone. Existing app directories and unrelated config/state remain.
A failed package installation stops before changing shell files; rerun to continue.

Edit `Brewfile` to change the package list. To update shared settings, edit their
tracked files, then commit/push. On another Mac, `git pull` updates linked configs;
rerun setup when packages or file mappings change. Zed defaults are intentionally
first-install only: review/copy new defaults explicitly for an existing Zed setup.

Machine-specific additions go in these **untracked home-directory files**:

- `~/.zshrc.local`: interactive aliases, exports, explicit `keyenv` calls.
- `~/.zshenv.local`: quiet PATH/environment changes needed by tools and scripts.
- `~/.zprofile.local`: login-shell-only additions.

The old personal Mac's private exports were preserved in `.zshrc.local`;
they are not part of the portable setup. Its original `.zsh-extra` remains in the backup.

`keyset`, `keyenv`, `keyget`, `keydel`, and `keylist` remain available as explicit
macOS Keychain helpers. The shared shell never automatically reads the Keychain.

## Finishing a new machine

- **GitHub:** use `./setup.sh --github-ssh` on the first run, or
  `./setup.sh --config-only --github-ssh` afterward. GitHub CLI handles browser
  sign-in, finds existing keys, and offers to generate/upload a key when missing.
  Choose a passphrase. The private key stays on this Mac; only its public key goes
  to GitHub. Normal setup reruns do not launch sign-in. For HTTPS instead, run
  `gh auth login` and `gh auth setup-git`.
  An incoming SSH login key only lets another machine reach this Mac; it does not
  authenticate this Mac to GitHub. Private keys and credential helpers are not copied.
- **Shell history:** Atuin is installed and initialized. `atuin import zsh` imports
  history already on this machine. Use `atuin login` and `atuin sync` if you already
  use its sync service; neither is required for local history search.
- **Other development tools:** the personal Mac also has Rust/rustup, Bun, tmux,
  lazygit and glow. These are optional, not part of the small default install.
  Add the last three to `Brewfile` if desired; install Rust/Bun only when needed.
- **Local secrets:** recreate needed Keychain entries and private overrides on the
  new machine, or use the selective SSH transfer below. Do not copy old exported
  tokens wholesale. An expired `GH_TOKEN` or `GITHUB_TOKEN` can override a valid
  `gh auth login`.

### Private environment settings and credentials

Ordinary preferences belong in the tracked shell (`AWS_DEFAULT_REGION=us-east-1`,
`RUST_BACKTRACE=full`, paths and editor defaults). Machine-only overrides belong in
`~/.zshenv.local` or `~/.zshrc.local`. Setup never publishes these files.

The shared `dotfiles-credentials` command inventories custom shell credentials by
name and transfers selected groups. Values stay in macOS Keychain. It uses Python
3.9+ supplied by Apple's command-line tools, with no third-party dependencies.

```sh
keycheck              # names and presence only; never values
keyload huggingface   # export this group's values into the current shell
keyload npm
keyload docker
```

| Group | Keychain items | Environment when loaded |
| --- | --- | --- |
| `huggingface` | `HF_TOKEN` | `HF_TOKEN` |
| `npm` | `NPM_TOKEN` | `NPM_TOKEN` |
| `docker` | `DOCKER_HUB_USERNAME`, `DOCKER_TOKEN` | Both, plus `DOCKER_HUB_PASSWORD` as an alias of `DOCKER_TOKEN` |
| `github-pat` | `GITHUB_PERSONAL_ACCESS_TOKEN` | Same name; only if a separate integration needs a PAT |

Old `GH_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SESSION_TOKEN`, and a conflicting
`NPM_TOKEN_LEGACY_BASH` are listed separately for review. Normal group loading and
transfer exclude them. Presence means stored, not that a provider accepted it.
Use GitHub CLI's own login for Git/gh and AWS SSO for AWS work.

To consolidate the old personal shell layout once (safe to repeat):

```sh
dotfiles-credentials migrate
```

It reads literal credential assignments and recognized aliases in `.zshrc.local`
and `.bash_profile`, verifies Keychain storage before removing plaintext, and
removes automatic credential exports. Existing different values cause it to stop;
the old Bash npm value is retained separately if it differs from the active Keychain
value. Private rollback copies live in `~/.local/state/dotfiles/credential-backups/`.
Those copies contain the old secrets: retain privately or delete after validating
your services. Open a fresh terminal after migration; existing processes still
have their previously exported values.

**Transfer to another configured Mac:** update/run setup on both machines first.
From the source Mac, select the groups you actually want to send:

```sh
dotfiles-credentials transfer farself@192.168.1.98 huggingface npm docker
```

This uses already-trusted SSH and sends values directly to the receiving Mac's
Keychain over encrypted SSH stdin. There is no export file. The receiver uses its
own macOS account, so different account names are supported. Matching entries are
retained; different existing entries stop the import. A failed partial transfer can
be retried with the same groups. Run the transfer from an interactive terminal.
If the receiving Keychain is locked, the helper asks for that Mac's Keychain
password (normally its login password) at a hidden prompt. It forwards the password
over the same encrypted SSH connection and unlocks with Apple's Keychain API.
Neither the password nor the selected tokens enter command arguments or files.
Tokens are read and sent only after the receiver confirms it is ready.

Unlock and import stay in one SSH session: a separate `ssh ... security
unlock-keychain` command does **not** unlock a later SSH connection. A desktop login
also does not guarantee that SSH can access the Keychain. Update dotfiles on both
Macs before transferring. Item-specific access approval may still be necessary
locally. No Keychain protection or lock setting is disabled.
Check with `keycheck` on the destination afterward, then use `keyload <group>`.

Keep a password-manager copy (for example in Bitwarden) when you need an independent
recovery source. To add a new item manually, enter it through the hidden prompt:

```sh
keyset HF_TOKEN
keyenv HF_TOKEN
```

`keyset` stores it under the current macOS account. `keyenv` exports it into the
current shell without printing it. If you need automatic interactive-shell
loading, add `keyenv HF_TOKEN` to `~/.zshrc.local`; the file contains the lookup,
not the value. Only enable lookups after importing the items. Prefer explicit
loading for tokens used occasionally. Avoid `keyget` in recorded/agent sessions:
it prints the secret. Keychain may ask you to authorize access locally.

Application-owned sign-ins stay with their applications: GitHub CLI, AWS SSO,
Docker Desktop, Zed integrations, Claude and Codex. Reauthenticate those on the
new machine; do not copy whole Keychain databases or token caches. The helper
intentionally handles the listed custom shell groups, not every credential on a Mac.
Do not assume custom Keychain items have synced just because both Macs use the
same Apple account. Project-local `.env` files are also outside this migration.

### GitHub SSH after sign-in

To remember the passphrase, use Apple's `/usr/bin/ssh-add --apple-use-keychain`
with the private-key path shown by GitHub CLI. For its usual default:

```sh
/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

If you want SSH to reuse Keychain automatically, merge this into your existing
`~/.ssh/config` using the actual key path; do not replace your other host entries:

```sshconfig
Host github.com
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
```

An existing HTTPS clone keeps its remote. To switch this checkout after signing in:

```sh
git remote set-url origin git@github.com:GeorgeLeePatterson/dotfiles.git
```

### Navigation shortcuts

| Command | Behavior |
| --- | --- |
| `cd path` | Enter an exact directory and list its contents in a terminal |
| `cd name` / `z name` | Jump to a matching directory learned by zoxide |
| `zi name` | Choose interactively among zoxide matches |
| `j` | Search directories under your home with a tree preview |
| `ls` | eza, including hidden files, one per line |
| `la` | Detailed one-level listing, icons and Git information |
| `li` / `ll` | Two-level trees; `li` also hides dependencies and build directories |

Zoxide learns directories as you visit them; its history is not copied between
machines. Non-terminal scripts retain ordinary, quiet `cd` behavior.

### Removing the short-lived fnm setup

After pulling these changes and running `./setup.sh`, open a new terminal. Check:

```sh
command -v nvm
command -v node       # should be under ~/.nvm/versions/node/
node --version
brew uninstall fnm
```

This removes fnm itself. Its downloaded Node versions are left on disk; setup
does not delete runtime data. There are no fnm hooks in the shared shell anymore.

## Small checks

```sh
./scripts/check.sh
```

Checks syntax, a disposable-home installation, identity defaults/preservation,
project directories, repeat-run backups/includes, existing Zed settings, cloning
directly into `.config`, and quiet shell startup. It does not
install packages or change your real home directory.

The supported target is macOS (Apple Silicon or Intel), with the system Bash and
Zsh. This is intentionally not a cross-platform dotfiles framework. Homebrew packages
are maintained releases, not a frozen lockfile.

References: [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile),
[Homebrew installation](https://brew.sh/), [NVM](https://github.com/nvm-sh/nvm),
[eza](https://github.com/eza-community/eza), [zoxide](https://github.com/ajeetdsouza/zoxide),
[GitHub CLI sign-in](https://cli.github.com/manual/gh_auth_login),
[GitHub SSH / macOS Keychain](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
