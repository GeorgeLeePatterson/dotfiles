#!/bin/bash

# Backup existing files
backup_dir=~/.dotfile_bk

{{#each dotter.files}}
{{#if (command_success "test -f {{this}}")}}
mkdir -p $backup_dir/{{@key}}
mv -hf "{{this}}" ~/.dotfile_bk/{{@key}} || echo "Could not move {{@key}}" && exit 1
{{/if}}
{{/each}}

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

# install rust
{{#if (is_executable "rustup")}}
echo "Rust installed"
{{else}}
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
{{/if}}
