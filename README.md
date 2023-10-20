# My Dots 🍬 🐜

The configurations I use to setup my environments for development productivity.

> NOTE: MacOS configuration. May work on other system, doubt it.

The configuration is meant to be as simple as possible: `.config` directory, already configured, that then uses `dotter` to deploy as little as possible (namely zsh related dots).

> NOTE: The `dotter` executable is included in the repo (`$HOME/.config/dotter`).

I prefer Rust tools when possible, so most of the tools configured are written in Rust.

## Neovim

Neovim (AstroNvim-based) dot files are [here](https://github.com/GeorgeLeePatterson/astrovim)

> NOTE: Will be moving to a fully custom setup at some point, will change submodule configuration.

## Screenshots

#### Neovim

Dashboard
![Dashboard](https://github.com/GeorgeLeePatterson/astrovim/blob/main/assets/dashboard.png)

Editor
![Editor](https://github.com/GeorgeLeePatterson/astrovim/blob/main/assets/editor.png)

Wezterm integration
![Wezterm integration](https://github.com/GeorgeLeePatterson/astrovim/blob/main/assets/wezterm.png)

#### Shell

- Terminal emulator: [Wezterm](https://wezfurlong.org/wezterm) (🦀)
- Prompt: [Starship](https://starship.rs/) (🦀)
- Shell: ZSH, [Antidote plugin manager](https://github.com/mattmc3/antidote)

#### Tools

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
- And many more

## Install

### Install brew packages, setup ZSH, configure Neovim, setup Bitwarden (optional)

> NOTE: Dotfiles, pre-deploy, and post-deploy are all handled by [dotter](https://github.com/SuperCuber/dotter)

1. Make backups of `$HOME/.config`, `$HOME/.local/share/nvim`, `$HOME/.local/state/nvim`
2. Clone repository into $HOME/.config:

```sh
git clone https://github.com/GeorgeLeePatterson/dotfiles $HOME/.config
```

3. Run installer (dotter 🦀): NOTE: may take a while, the .Brewfile will install all packages

```sh
$HOME/.config/dotter deploy
```

4. Source zshrc

```sh
source ~/.zshenv && source ~/.zshrc
```

5. Run additional tasks using [just](https://github.com/casey/just)

```sh
cd $HOME/.config

# Update gh repo
just update-git

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
