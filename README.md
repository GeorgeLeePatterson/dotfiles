# My Dots 🍬 🐜

Neovim (AstroNvim) dot files are [here](https://github.com/GeorgeLeePatterson/astrovim)

## Install

### Install brew packages, setup ZSH, configure Neovim, setup Bitwarden (optional)

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
