#!/usr/bin/env just --justfile

set shell := ["zsh", "-cu"]

# Variables

copilot_user := "GeorgeLeePatterson"
copilot_token := `which rbw > /dev/null 2>&1 && rbw get COPILOT_OAUTH_TOKEN || echo ""`

# Bitwarden

email := "patterson.george@gmail.com"

# gh ssh variables

gh_pub := ""
gh_key := ""

default:
    @just --choose

# Update Neovim
update-neovim:
    @cd ~/.config && git pull --recurse-submodules
    ln -s ~/.config/nvim-user ~/.config/nvim/lua/user || true
    ln -s ~/.config/nvim-user/ftplugin ~/.config/nvim/ftplugin/ || true
    ln -s ~/.config/nvim-user/after ~/.config/nvim/after/ || true

# install and configure bitwarden
bw:
    brew install pinentry-mac
    mkdir -p ~/.gnupg && touch ~/.gnupg/gpg-agent.conf
    echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" > ~/.gnupg/gpg-agent.conf
    ln -s $(which pinentry-mac) $(brew --prefix)/bin/pinentry
    cargo install rbw
    open "https://vault.bitwarden.com/#/settings/security/security-keys"
    rbw config set email {{ email }} && rbw register

# store copilot token
authorize-copilot:
    #!/usr/bin/env bash
    set -euxo pipefail

    TOKEN={{ copilot_token }}
    if [ -z $TOKEN ]; then
     echo "No token found, please set copilot_token or configure bitwarden (rbw)";
     exit 1;
    fi

    test -f ~/.config/github-copilot/hosts.json \
     && echo "Copilot setup" \
     || echo "{\"github.com\":{\"user\":\"{{ copilot_user }}\",\"oauth_token\":\"{{ copilot_token }}\"}}" > ~/.config/github-copilot/hosts.json

# setup ssh key
gh-ssh-key:
    #!/usr/bin/env bash
    set -euxo pipefail

    ghp={{ gh_pub }}
    ghk={{ gh_key }}

    if [ -z $ghp ] || [ -z $ghk ]; then
     echo "Please set gh_pub and gh_key"
     exit 1
    fi

    gh_ssh_pub=$(rbw get --raw --full --field=$ghp $ghk | jq -r ".fields[0].value")
    gh_ssh_key=$(rbw get --raw --full $ghk | jq -r ".notes")

    test -f ~/.ssh/shared_id_ed25519 \
     && echo "SSH key already setup" \
     || echo "$gh_ssh_key" > ~/.ssh/shared_id_ed25519 && chmod 600 ~/.ssh/shared_id_ed25519
    test -f ~/.ssh/shared_id_ed25519.pub \
     && echo "SSH pub key already setup" \
     || echo "$gh_ssh_pub" > ~/.ssh/shared_id_ed25519.pub && chmod 600 ~/.ssh/shared_id_ed25519.pub

# All commands
all:
    @just update-neovim
    just bw
    just authorize-copilot
    echo "\n\t** GH SSH KEY NOT RUN! Run 'just gh-ssh-key' and provide 'gh_pub' and 'gh_key' **"
