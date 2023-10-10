#!/bin/zsh

# test if zsh works
echo "Sourcing zsh files"
/bin/zsh -c 'source ~/.zshenv || "could not source zshenv"'
/bin/zsh -c 'source ~/.zshrc || "could not source zshrc"'

# install rust
{{#if (is_executable "rustup")}}
echo "Rust installed"
{{else}}
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
{{/if}}

# install homebrew
{{#if (is_executable "brew")}}
echo "Homebrew installed"
{{else}}
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
{{/if}}

# install brewfile
export HOMEBREW_BUNDLE_BREWFILE=~/.config/.Brewfile
export HOMEBREW_CASK_OPTS="--appdir=$HOME/MyApplications"
brew tap Homebrew/bundle
brew bundle --file $HOMEBREW_BUNDLE_BREWFILE -v

# install docker separately
{{#if (is_executable "docker")}}
echo "Docker installed"
{{else}}
brew install --cask docker
{{/if}}

# install nerd fonts separately
brew tap homebrew/cask-fonts
brew search '/font-.*-nerd-font/' | awk '{ print $1 }' | xargs -I{} brew install --cask {} || true

# create local script dir
mkdir -p ~/.local/bin

# install starship
{{#if (is_executable "starship")}}
echo "Starship installed"
{{else}}
curl -sS https://starship.rs/install.sh | sh
{{/if}}

# configure gdu
{{#if (is_executable "gdu")}}
echo "gdu linked"
{{else}}
ln -s $(which gdu-go) ~/.local/bin/gdu
{{/if}}

# configure curly lines in wezterm
if ! test -f ~/.terminfo; then
  tempfile=$(mktemp) \
    && curl -o $tempfile https://raw.githubusercontent.com/wez/wezterm/master/termwiz/data/wezterm.terminfo \
    && tic -x -o ~/.terminfo $tempfile \
    && rm $tempfile
fi

# make sure zsh shell
# chsh -s $(which zsh)
