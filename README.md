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
3. Sets up Node 24 with fnm when no fnm default exists. Existing fnm defaults stay.
4. Links `.zshenv`, `.zprofile`, `.zshrc`, the prompt, Ghostty and small tool configs.
5. Includes shared Git preferences without replacing your Git identity or sign-ins.
6. Copies sanitized Zed settings and keybindings only if those files do not exist.

Open a new terminal afterward. Use Ghostty for the current dark/light themes and
JetBrainsMono Nerd Font. Install Ghostty, Brave, Slack, Claude and Codex separately;
this repo is the terminal setup, not an application/account installer.

## What is included

- **Shell:** autosuggestions, syntax highlighting, fuzzy tab completion, Starship.
- **Navigation/history:** zoxide (`cd` + listing in a terminal), Atuin, fzf, broot,
  `j` for directory search, `ls`/`la`/`li`/`ll` using eza.
- **Daily CLI:** Git, GitHub CLI, AWS CLI, delta, Git LFS, jq, ripgrep, fd, bat, tree,
  btop, Micro and just.
- **Development:** fnm/Node 24, pnpm and uv. Projects choose their other runtimes/tools.
- **Editor defaults:** Ghostty and Zed. Existing Zed settings are preserved, including
  any local integrations. The defaults omit account/MCP secrets and are copied rather
  than linked, so credentials Zed saves cannot enter this repo through a symlink.

Git identity, `gh auth login`, AWS sign-in, native-agent sign-ins and optional Atuin
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
they are not part of the portable setup. Its original `.zsh-extra` remains in the backup. NVM is no longer initialized by the shared
shell. Its installations are left on disk; fnm is the single managed Node runtime.

`keyset`, `keyenv`, `keyget`, `keydel`, and `keylist` remain available as explicit
macOS Keychain helpers. The shared shell never automatically reads the Keychain.

## Small checks

```sh
./scripts/check.sh
```

Checks syntax, a disposable-home installation, repeat-run backups/includes, existing
Zed settings, cloning directly into `.config`, and quiet shell startup. It does not
install packages or change your real home directory.

The supported target is macOS (Apple Silicon or Intel), with the system Bash and
Zsh. This is intentionally not a cross-platform dotfiles framework. Homebrew packages
are maintained releases, not a frozen lockfile.

References: [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile),
[Homebrew installation](https://brew.sh/), [fnm](https://github.com/Schniz/fnm).
