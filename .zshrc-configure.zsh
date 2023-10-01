#
#
#    Keep Zsh configurations in .config...
#
#

# ########################
# Environment variables  #
# ########################
#
export LANG=en_US.UTF-8
export EDITOR=micro
export VISUAL="$EDITOR"
export PAGER=less
export ZDOTDIR=$HOME
export XDG_CONFIG_HOME=$HOME/.config
export KERNEL_NAME=$( uname | tr '[:upper:]' '[:lower:]' )
export TERM=wezterm
export FZF_DEFAULT_COMMAND='rg --no-messages --files --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_DEFAULT_OPTS="--no-separator --layout=reverse --inline-info"

# zoxide directory preview options
export _ZO_FZF_OPTS="--no-sort --keep-right --height=50% --info=inline --layout=reverse --exit-0 --select-1 --bind=ctrl-z:ignore --preview='\command exa --long --all {2..}' --preview-window=right"

# neovim
export XDG_STATE_HOME=~/.local/state
export XDG_DATA_HOME=~/.local/share
export XDG_CONFIG_HOME=~/.config
export NVIM_SWAP=$XDG_STATE_HOME/nvim/swap

# history
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"       # The path to the history file.
HISTSIZE=1000000000              # The maximum number of events to save in the internal history.
SAVEHIST=1000000000              # The maximum number of events to save in the history file.

setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY               # Do not execute immediately upon history expansion.

setopt complete_in_word

# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
zstyle ':fzf-tab:complete:tldr:argument-1' fzf-preview 'tldr --color always $word'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'
# exclude .. and . from completion
zstyle ':completion:*' special-dirs false
# show hidden files in completion
setopt glob_dots

# remove duplicat entries from $PATH
# zsh uses $path array along with $PATH 
typeset -U PATH path

# brew
# NOTE: brew re-orders path, so try and keep it first
eval "$(/opt/homebrew/bin/brew shellenv)"
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

# poetry
poetry() {
  command -v poetry >/dev/null || export PATH="$XDG_CONFIG_HOME/.local/bin:$PATH"
  poetry "$@"
}

# prefer using fnm over nvm
eval "$(fnm env --use-on-cd)"

# # THIS IS 90% OF LOAD TIME, RUN FUNCTION IF NECESSARY
# #nvm
# export NVM_DIR="$HOME/.nvm"
# if [[ -d "${NVM_DIR}" ]]; then
#   pyenv () {
#     if ! (($path[(Ie)${NVM_DIR}/bin])); then
#       path[1,0]="${NVM_DIR}/bin"
#     fi
#     [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
#     [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  
#     nvm "$@"
#     unfunction nvm 
#   }
# else
#   unset NVM_DIR 
# fi

# cargo
source "$HOME/.cargo/env"

# for numpy
export OPENBLAS="$(brew --prefix openblas)"

# antidote
zsh_plugins=${XDG_CONFIG_HOME:-~/.config}/.zsh_plugins.zsh
antidote_path=$(brew --prefix)/opt/antidote/share/antidote
[[ -f ${zsh_plugins:r}.txt ]] || touch ${zsh_plugins:r}.txt
source $antidote_path/antidote.zsh
antidote load ${zsh_plugins:r}.txt

# zsh plugin configuration
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/opt/homebrew/share/zsh-syntax-highlighting/highlighters
export ZSH_AUTOSUGGEST_STRATEGY=(history completion) 

# bind up/down to substring history
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# hashicorp setup
hashi_comp() {
  complete -o nospace -C /opt/homebrew/bin/nomad nomad
  complete -o nospace -C /opt/homebrew/bin/terraform terraform
}

# Manual additions
export PATH=/usr/local/bin:$PATH

# ########################
# ALIASES			  			   #
# ########################
#
# exa aliases
alias ls='exa -a -1'
alias la='exa -1 --level=1 --tree --icons --classify --colour=auto --sort=name --group-directories-first --header --modified --created --git --binary -la'
alias ll="exa -1 --level=2 --icons --tree --ignore-glob='target|node_modules|venv|env|.vscode|.DS_Store|.cache|__pycache__' --classify --colour=auto --sort=name --group-directories-first --header --modified --created --git --binary --group -la"

# broot alias
alias br='br -dsi'

# wezter + nvim
alias nvim='env TERM=wezterm nvim'

# gdu
alias gdu='gdu-go'

# ########################
# APPLICATION SETUP      #
# ########################
#
# atuin
eval "$(atuin init zsh --disable-up-arrow)"

# broot
source "$HOME/.config/broot/launcher/bash/br"

# starship
eval "$(starship init zsh)"

# create completions
autoload -Uz compinit && compinit
# autoload -Uz promptinit && promptinit
