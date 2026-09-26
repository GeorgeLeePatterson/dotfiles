# My Mac setup

A small, personal macOS setup: one script, a base Brewfile, optional profiles, and plain Zsh files. No Dotter,
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
2. Installs missing packages from `Brewfile`, including PostgreSQL client tools and
  Docker Desktop, without upgrading or removing others. It preserves an existing
   manually installed Docker app. Homebrew may request administrator approval for
   Docker's system CLI links. Packages use normal permissions; private configuration
   uses owner-only permissions. No database, container, or VM is started.
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

Open a new terminal afterward and run `dotfiles-doctor`. Use Ghostty for the current
dark/light themes and JetBrainsMono Nerd Font. Optional profiles use the same script:

```sh
./setup.sh --apps          # Brave, Ghostty, Slack, Zed, Claude and Codex desktop apps
./setup.sh --dev           # tmux, lazygit and glow
./setup.sh --apps --dev    # both, plus the baseline tools
```

Existing manual apps in `/Applications` or `~/Applications` are retained. Native
Claude/Codex CLI installations and their account sign-ins remain app-specific;
the desktop app profile does not pretend to provision those accounts.
Open Docker Desktop once to complete its first-launch setup. Its bundled CLI is
on PATH even before Docker creates its optional symlinks. `docker compose` and
`docker buildx` come with Desktop. Dotfiles does not install a second Colima VM or
change Docker contexts. Farself's privately managed containers remain separate.
Project commands own PostgreSQL versions, ports, database contents and `.env` files;
installing `psql` is not the same thing as running a database server.

## What is included

- **Shell:** autosuggestions, syntax highlighting, fuzzy tab completion, Starship.
- **Navigation/history:** zoxide (`cd` + listing in a terminal), Atuin, fzf, broot,
  `j` for directory search, `ls`/`la`/`li`/`ll` using eza.
- **Daily CLI:** Git, GitHub CLI, AWS CLI, delta, Git LFS, jq, ripgrep, fd, bat, tree,
  btop, Micro, just and PostgreSQL clients (`psql`, `pg_dump`, `pg_restore`).
- **Development:** NVM/Node 24, pnpm and uv. Node works in terminal and SSH/tool
  shells. Use `nvm use` in projects with `.nvmrc`; `nvm alias default 24` changes
  the default. Opening a subshell preserves a version selected with `nvm use`.
  Docker Desktop is baseline. Projects choose their database/server versions and other runtimes.
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

Legacy credential exports can be consolidated into Keychain using `dotfiles-credentials migrate`
below. Private rollback backups are excluded from Git; they are not portable configuration.

`keyset`, `keyenv`, `keyget`, `keydel`, and `keylist` remain available as explicit
macOS Keychain helpers. Everyday groups load automatically when the current session can access the Keychain.

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
- **Other development tools:** `--dev` installs tmux, lazygit and glow. Rust/rustup,
  Bun and project-specific SDKs remain optional; install them when a project needs them.
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

New Zsh sessions automatically load the `huggingface`, `npm`, and `docker` groups
when their Keychain is accessible. This includes noninteractive commands used by
GUI-launched agents, not just terminal windows. No per-terminal commands are needed.
Nonempty inherited overrides win; missing groups or a locked Keychain are skipped
quietly. The helper does not unlock Keychains or publish credentials into the global
macOS GUI environment. Existing item access controls still apply and macOS may
require approval for an item whose access has not already been granted.

```sh
keycheck              # stored names/presence, never values
keyload npm           # optional: refresh an already-open terminal after a change
# For Bash or a tool that directly launches a process instead of Zsh:
dotfiles-credentials run npm -- pnpm install
```

`run` loads only the requested group and refuses to launch the command if it cannot
obtain that group. Zsh startup uses an internal `shell-env` protocol; do not run it
in logs or an agent transcript because it carries exports, not diagnostics.

**SSH is a distinct login/security session.** A token can be stored on the Mac and
available in its desktop session while inaccessible over SSH. Check with
`dotfiles-doctor` in the session that runs the work. Use the signed-in desktop
session, or unlock Keychain interactively and run the command in that *same SSH
session*. A separate SSH unlock does not persist to later connections. An app that
launches Bash or a program directly can use `dotfiles-credentials run`; switching to
an interactive shell cannot bypass a locked Keychain.

Set `DOTFILES_KEYCHAIN_AUTOLOAD=0` in private `~/.zshenv.local` to disable automatic
loading for all shells on a machine. A setting in `~/.zshrc.local` disables it only
for interactive shells. `GH_TOKEN`, old AWS session tokens and arbitrary project
`.env` files are never automatically exported.

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
removes the old scattered credential exports. The shared shell handles automatic
loading of the three everyday groups. Existing different values cause it to stop;
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
New Zsh commands on the destination load the three everyday groups when that
session has Keychain access. Open a fresh terminal after transferring. `keyload <group>` is also available to refresh an existing terminal.

Keep a password-manager copy (for example in Bitwarden) when you need an independent
recovery source. To add a new item manually, enter it through the hidden prompt:

```sh
keyset HF_TOKEN
keyenv HF_TOKEN
```

`keyset` stores it under the current macOS account. `keyenv` exports it into the
current shell without printing it. The three everyday groups load automatically;
additional occasional tokens can still use `keyenv` or `keyload github-pat`.
Avoid `keyget` in recorded/agent sessions:
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

### NVM replaces the old fnm setup

After pulling these changes and running `./setup.sh`, open a new terminal. Check:

```sh
command -v nvm
command -v node       # should be under ~/.nvm/versions/node/
node --version
brew uninstall fnm
```

NVM is the only Node manager initialized by the shared shell. New shells remove
inherited `FNM_*` variables and fnm runtime paths before initializing NVM, including
stale paths retained by a terminal app. `dotfiles-doctor` checks which manager
actually supplies Node and identifies obsolete fnm data.

Homebrew uninstall does not remove fnm's downloaded Node versions or session
links. When retiring an older installation, inspect `~/.local/share/fnm` (or
`~/.fnm` / `~/Library/Application Support/fnm`) and
`~/.local/state/fnm_multishells`. Preserve any needed global packages and confirm
no running processes depend on those runtimes before deleting them. Setup does
not silently delete runtime data on another machine.

An already-open shell may still hold fnm's old directory-change hook in memory.
After cleanup, close/reopen the terminal or run `exec zsh -l` once. New terminals
do not require any manual initialization.

## Check the machine you are actually using

```sh
dotfiles-doctor
dotfiles-doctor --apps --dev
dotfiles-doctor --project ~/projects/tallio/hospice-os
```

This read-only report identifies the host/account, executable paths, actual app
bundles, Docker CLI/plugins versus engine availability, Git identity, GitHub login,
Keychain storage versus current environment, legacy shell credential assignments,
and `.npmrc` environment references. It never prints credential values, starts a
service, installs project dependencies, or accesses production databases. Registry
permissions/expiry and browser sign-in are separate from an installed app or stored
token. Run the check in the same session that will do the work.

## Small checks

```sh
./scripts/check.sh
```

Checks syntax, a disposable-home installation, identity defaults/preservation,
project directories, repeat-run backups/includes, existing Zed settings, cloning
directly into `.config`, and quiet shell startup. Credential tests use synthetic entries, including noninteractive
startup, locked sessions, overrides, selective command execution and shell quoting. It does not
install packages or change your real home directory.

The supported target is macOS (Apple Silicon or Intel), with the system Bash and
Zsh. This is intentionally not a cross-platform dotfiles framework. Homebrew packages
are maintained releases, not a frozen lockfile.

References: [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile),
[Homebrew installation](https://brew.sh/), [PostgreSQL clients](https://formulae.brew.sh/formula/libpq),
[Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/), [NVM](https://github.com/nvm-sh/nvm),
[eza](https://github.com/eza-community/eza), [zoxide](https://github.com/ajeetdsouza/zoxide),
[GitHub CLI sign-in](https://cli.github.com/manual/gh_auth_login),
[GitHub SSH / macOS Keychain](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
