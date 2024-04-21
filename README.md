# Dots 🍬 🐜

The configurations I use to setup my environments for development productivity.

> NOTE: MacOS configuration. May work on other system, doubt it.

The configuration is meant to be as simple as possible: `.config` directory, already configured, that then uses `dotter` to deploy as little as possible (namely zsh related dots).

> NOTE: The `dotter` executable is included in the repo (`$HOME/.config/dotter`).

I prefer Rust tools when possible, so most of the tools configured are written in Rust.

## Neovim

Neovim (AstroNvim-based) dot files are [here](https://github.com/GeorgeLeePatterson/astrovim)

> NOTE: No longer using Neovim 🫠. Have switched over to zed. To see the configuration I was using, visit the link above.

### Shell

- Terminal emulator: [Wezterm](https://wezfurlong.org/wezterm) (🦀)
- Prompt: [Starship](https://starship.rs/) (🦀)
- Shell: ZSH, [Antidote plugin manager](https://github.com/mattmc3/antidote)
- IDE: [Zed](https://zed.dev/releases/preview) (🦀)

### Tools

- zoxide (🦀): Switch between directories fast
- neovide (🦀): Excellent, fast, and beautiful Neovim GUI.
- bottom (🦀): Resource utilization
- xsv (🦀): Best command line csv parsing, querying, and more
- fd (🦀): Faster find alternative
- ripgrep (🦀): Blazing fast grep alternative
- dust (🦀): Better du alternative
- eza (🦀): Better ls
- bat (🦀): Better cat
- broot (🦀): Interactive terminal file browser
- atuin (🦀): Command history (ctrl-r replacement)
- tokei (🦀): Count lines of code
- delta (🦀): Better git diff terminal tool
- just (🦀): Awesome make like alternative
- fnm (🦀): Nvm alternative
- dotter (🦀): Dotfile management tool (executable is included)
- glow: Preview markdown in the terminal
- fzf: Command line fuzzy finder
- btop: C++ based resource monitor (I use this a LOT)
- pyenv: Manage python environments
- poetry: Python project management
- jq: Excellent command line json parser
- All NerdFonts
- And others

## Install

### Dotter: Install brew packages, setup ZSH, configure Neovim, setup Bitwarden (optional)

> NOTE: Dotfiles, pre-deploy, and post-deploy are all handled by [dotter](https://github.com/SuperCuber/dotter)

1. Make backups of `$HOME/.config`, `$HOME/.local/share/nvim`, `$HOME/.local/state/nvim`

   ```bash
   # Example script to backup list of files
   for f in "$HOME/.config" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim"; do mv ${f} "${f}.bak" || exit 1; done;
   ```

2. Clone repository into $HOME/.config:

   ```bash
   git clone https://github.com/GeorgeLeePatterson/dotfiles $HOME/.config
   ```

3. Copy and rename `.dotter/local.tmpl.toml` to `.dotter/local.toml` and update your git user name and email (for .gitconfig)

   ```bash
   mv $HOME/.config/.dotter/local.tmpl.toml $HOME/.config/.dotter/local.toml
   edit $HOME/.config/.dotter/local.toml
   ```

4. Run installer (dotter 🦀): NOTE: may take a while, the .Brewfile will install all packages

   > Note: If you've already run dotter once, you may need to run `dotter undeploy` to refresh the templates

   ```bash
   $HOME/.config/dotter deploy
   ```

5. Source zshrc

   ```bash
   source ~/.zshenv && source ~/.zshrc
   ```

6. Run additional tasks using [just](https://github.com/casey/just)

   ```bash
   cd $HOME/.config

   # Update Neovim, create symlinks
   just update-neovim

   # If you have bitwarden, you can use the following to
   # setup bw, rbw, and ssh keys
   just bw email=YOUR_EMAIL

   # If you have copilot setup, you can integrate with Neovim:
   # NOTE: the token will be pulled from bitwarden. To skip that
   # just provide the token using `copilot_token=YOUR_TOKEN`
   just authorize-copilot copilot_user=USERNAME

   # Finally setup your GH ssh keys to access your private repo
   # NOTE: provide `gh_pub` and `gh_key`. They are the names of
   # the bitwarden entries for each.
   just gh-ssh-key gh_pub=BW_GH_PUB gh_key=BW_GH_KEY
   ```
