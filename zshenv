setopt all_export pipe_fail glob_assign

# ########################
# Environment variables  #
# ########################

export ZSH_ENV_SOURCED=1 # Helps to keep track when this occurs

export LANG=en_US.UTF-8

# set default term (for apps that don't source zshrc)
export TERM="xterm-256color"

# editor
export EDITOR=micro # I use the simpler micro for quick editing. neovim for IDE
export VISUAL="$EDITOR"

# pager
which bat > /dev/null 2>&1 && export PAGER=bat || export PAGER=less
export BAT_PAGER="less -RF"

# XDG
export XDG_STATE_HOME=$HOME/.local/state
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/.config

# kernel
export KERNEL_NAME=$( uname | tr '[:upper:]' '[:lower:]' )

# zsh 
export ZDOTDIR="$HOME"
export HISTFILE="${ZDOTDIR}/.zsh_history"       # The path to the history file.
export HISTSIZE=1000000000              # The maximum number of events to save in the internal history.
export SAVEHIST=1000000000              # The maximum number of events to save in the history file.

# fzf 
export FZF_DEFAULT_COMMAND='rg --no-messages --files --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_DEFAULT_OPTS="--no-separator --layout=reverse --inline-info"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
 --color fg:#ebdbb2,bg:#282828,hl:#fabd2f,fg+:#ebdbb2,bg+:#3c3836,hl+:#fabd2f
 --color info:#83a598,prompt:#bdae93,spinner:#fabd2f,pointer:#83a598,marker:#fe8019,header:#665c54'
export FZF_DEFAULT_OPTS="--height 60% \
--border sharp \
--layout reverse \
--color '$FZF_COLORS' \
--prompt '∷ ' \
--pointer ▶ \
--marker ⇒"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -n 10'"

# zoxide directory preview options
export _ZO_FZF_OPTS="--no-sort --keep-right --height=50% --info=inline --layout=reverse --exit-0 --select-1 --bind=ctrl-z:ignore --preview='\command eza --long --all {2..}' --preview-window=right"

# neovim
export NVIM_SWAP=$XDG_STATE_HOME/nvim/swap

# Vale
export VALE_CONFIG_PATH=$XDG_CONFIG_HOME/.vale.ini

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

# pyenv
eval "$(pyenv init --path)"

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
