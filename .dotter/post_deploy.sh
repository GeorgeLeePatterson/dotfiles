#!/bin/zsh

# test if zsh works
echo "Sourcing zsh files"
exec /bin/zsh
# /bin/zsh -c 'source ~/.zshenv' || "could not source zshenv"
# /bin/zsh -c 'source ~/.zshrc' || "could not source zshrc"

# install docker separately
{{#if (is_executable "docker")}}
echo "Docker installed"
{{else}}
brew install --cask docker
{{/if}}

install_fonts()
{
  brew tap homebrew/cask-fonts
  brew search '/font-.*-nerd-font/' | awk '{ print $1 }' | xargs -I{} brew install --cask {} || true
}

# install nerd fonts separately
if [[ -z "${DOTTER_DEPLOYED}" ]]
then
  install_fonts
else
  echo "\n\n\tSkipping fonts as dotter has already been deployed.\n\t==> To re-run, call command 'install_fonts'\n\n"
fi

# create local script dir
mkdir -p ~/.local/bin

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
