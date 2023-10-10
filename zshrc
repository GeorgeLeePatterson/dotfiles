#
#
#    Keep Zsh configurations in .config...
#
#

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
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
zstyle ':fzf-tab:complete:tldr:argument-1' fzf-preview 'tldr --color always $word'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'
# exclude .. and . from completion
zstyle ':completion:*' special-dirs false
# show hidden files in completion
setopt glob_dots

#
# PLUGINS
#

# # for numpy
# export OPENBLAS="$(brew --prefix openblas)"

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

# ########################
# ALIASES			  			   #
# ########################

{{#if (is_executable "eza")}}
# eza aliases
alias ls='eza -a -1'
alias la='eza -1 --level=1 --tree --icons --classify --colour=auto --sort=name --group-directories-first --header --modified --created --git --binary -la'
alias ll="eza -1 --level=2 --icons --tree --ignore-glob='target|node_modules|venv|env|.vscode|.DS_Store|.cache|__pycache__' --classify --colour=auto --sort=name --group-directories-first --header --modified --created --git --binary --group -la"
{{else}}
alias ls="ls --color-auto"
alias la="ls -la"
{{/if}}

# broot alias
{{#if (is_executable "br")}}
alias br='br -dsi'
{{/if}}

# gdu
{{#if (is_executable "gdu-go")}}
alias gdu='gdu-go'
{{/if}}

# ########################
# APPLICATION SETUP      #
# ########################

# atuin
{{#if (is_executable "atuin")}}
eval "$(atuin init zsh --disable-up-arrow)"
{{/if}}

# broot
{{#if (is_executable "br")}}
source "$HOME/.config/broot/launcher/bash/br"
{{/if}}

# starship
eval "$(starship init zsh)"

# CD
{{#if (is_executable "zoxide")}}
eval "$(zoxide init {{#if dotter.packages.zsh}}zsh{{else}}bash{{/if}})"
{{/if}}
cd ()
{
    # Pass all arguments to cd
    {{#if (is_executable "zoxide")}}z{{else}}builtin cd{{/if}} "$@" || return $?
    ls
}

{{#if (is_executable "bat")}}
alias cat="bat"
{{/if}}

# fzf
{{#if (is_executable "fzf")}}
j ()  # Navigate with fzf
{
    {{#if (is_executable fd)}}
    find_command='fd . ~ --type d'
    {{else}}
    # Settle for not hiding gitignored stuff
    find_command='find ~ -type d'
    {{/if}}
    dir=$(eval $find_command | fzf --preview 'tree -CF -L 2 {+1}')
    fzf_return=$?
    [ $fzf_return = 0 ] && cd $dir || return $fzf_return
}
{{/if}}

upgrade_wezterm()
{
  brew upgrade --cask wezterm-nightly --no-quarantine --greedy-latest
}

# create completions
autoload -Uz compinit && compinit
# autoload -Uz promptinit && promptinit
