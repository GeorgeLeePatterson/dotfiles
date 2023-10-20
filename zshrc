#
#
#    Keep Zsh configurations in .config...
#
#

export ZSH_RC_SOURCED=1 # Helps to keep track when this occurs

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
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search # history-substring-search-up
bindkey '^[[B' down-line-or-beginning-search # history-substring-search-down

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
{{/if}}

# broot
{{#if (is_executable "broot")}}
alias broot="broot -dsi"
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

# broot => br
{{#if (is_executable "broot")}}
function br {
    local cmd cmd_file code
    cmd_file=$(mktemp)
    if broot --outcmd "$cmd_file" "$@"; then
        cmd=$(<"$cmd_file")
        command rm -f "$cmd_file"
        eval "$cmd"
    else
        code=$?
        command rm -f "$cmd_file"
        return "$code"
    fi
}
{{/if}}

# starship
{{#if (is_executable "starship")}}
eval "$(starship init zsh)"
{{/if}}

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

# Simple function to upgrade wezterm if on nightly
upgrade_wezterm()
{
  brew upgrade --cask wezterm-nightly --no-quarantine --greedy-latest
}

# create completions
autoload -Uz compinit && compinit

# install nerdfonts helper 
install_fonts()
{
  brew tap homebrew/cask-fonts
  brew search '/font-.*-nerd-font/' | awk '{ print $1 }' | xargs -I{} brew install --cask {} || true
}

# Startup splash
# To configure macchina (to change ascii for example), modify tomls under ~/.config/macchina
if [[ -f ~/.config/macchina/startup ]]; then
    source ~/.config/macchina/startup
elif which macchina > /dev/null 2>&1; then
    macchina
fi

# Keep track of dotter initialized
export DOTTER_DEPLOYED=1
