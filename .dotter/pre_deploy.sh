#!/bin/bash

exec /bin/zsh

# Backup existing files
backup_dir=~/.dotfile_bk

{{#each dotter.files}}
{{#if (command_success "test -f {{this}}")}}
mkdir -p $backup_dir/{{@key}}
mv -hf "{{this}}" ~/.dotfile_bk/{{@key}} || echo "Could not move {{@key}}" && exit 1
{{/if}}
{{/each}}

# install homebrew
{{#if (is_executable "/opt/homebrew/bin/brew")}}
echo "Homebrew installed"
{{else}}
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
{{/if}}

{{#if (is_executable "/opt/homebrew/bin/brew")}}
# install brewfile
BREW_BIN_PATH=/opt/homebrew/bin
export HOMEBREW_BUNDLE_BREWFILE=~/.config/.Brewfile
$BREW_BIN_PATH/brew tap Homebrew/bundle
$BREW_BIN_PATH/brew bundle --file $HOMEBREW_BUNDLE_BREWFILE -v
{{/if}}

# install rust
{{#if (is_executable "~/.cargo/bin/rustup")}}
echo "Rust installed"
{{else}}
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path -y --profile default
{{/if}}

# install starship
{{#if (is_executable "/usr/local/bin/starship")}}
echo "Starship installed"
{{else}}
curl -sS https://starship.rs/install.sh | sh -s -- -y
{{/if}}
