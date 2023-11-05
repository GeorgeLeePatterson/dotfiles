#!/bin/zsh

BREW_BIN_PATH=/opt/homebrew/bin
PATH="$BREW_BIN_PATH;$HOME/.cargo/bin;/usr/local/bin;$HOME/.local/bin;$PATH"

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

# Symlink vale ini
ln -s ~/.config/vale/vale.ini ~/.vale.ini || true


# make sure zsh shell
# chsh -s $(which zsh)

echo "\n\nTo use the new shell updates, be sure to reinitialize zsh:"
echo "\t==> source ~/.zshenv"
echo "\tor"
echo "\t==> exec /bin/zsh"

echo "\n\n**************************"
echo "To setup Neovim, Bitwarden, or Copilot, run the 'justfile' by executing 'just' in the '~/.config' directory"
echo "**************************\n\n"

