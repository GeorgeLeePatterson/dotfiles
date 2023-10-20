setopt all_export pipe_fail glob_assign

# ########################
# Environment variables  #
# ########################

export LANG=en_US.UTF-8
export EDITOR=micro
export VISUAL="$EDITOR"
export PAGER=less
export XDG_CONFIG_HOME=$HOME/.config
export KERNEL_NAME=$( uname | tr '[:upper:]' '[:lower:]' )
export TERM=wezterm
export ZSH_ENV_SOURCED=1 # Helps to keep track when this occurs

# fzf configuration
export FZF_DEFAULT_COMMAND='rg --no-messages --files --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_DEFAULT_OPTS="--no-separator --layout=reverse --inline-info"

# zoxide directory preview options
export _ZO_FZF_OPTS="--no-sort --keep-right --height=50% --info=inline --layout=reverse --exit-0 --select-1 --bind=ctrl-z:ignore --preview='\command eza --long --all {2..}' --preview-window=right"

# neovim
export XDG_STATE_HOME=~/.local/state
export XDG_DATA_HOME=~/.local/share
export XDG_CONFIG_HOME=~/.config
export NVIM_SWAP=$XDG_STATE_HOME/nvim/swap

# ########################
# PATH settings			 #
# ########################

typeset -U path

# pyenv - lazy load
PYENV_ROOT="${HOME}/.pyenv"
if [[ -d "${PYENV_ROOT}" ]]; then
  pyenv () {
    if ! (($path[(Ie)${PYENV_ROOT}/bin])); then
      path[1,0]="${PYENV_ROOT}/bin"
    fi
    eval "$(command pyenv init -)"
    pyenv "$@"
    unfunction pyenv
  }
else
  unset PYENV_ROOT
fi

# cargo
source "$HOME/.cargo/env"

# poetry, gdu, etc
export PATH="$XDG_CONFIG_HOME/.local/bin:$PATH"

# wezterm
export PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS"

# starship, etc
export PATH="/usr/local/bin:$PATH"

# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# prefer using fnm over nvm
eval "$(fnm env)"

# Setting some aliases here for neovim (no idea why they don't get sourced)

# gdu
if which gdu-go > /dev/null 2>&1; then
  alias gdu='gdu-go'
fi

# bat
if which bat > /dev/null 2>&1; then
  alias cat="bat"
fi

unsetopt all_export
