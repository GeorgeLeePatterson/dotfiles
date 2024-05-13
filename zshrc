export ZSH_RC_SOURCED=1 # Helps to keep track when this occurs

# ########################
#
# TERM
#
# ########################

# configure TERM for wezterm
if ! test -d "$HOME/.terminfo"; then
  tempfile=$(mktemp) \
    && curl -o $tempfile https://raw.githubusercontent.com/wez/wezterm/master/termwiz/data/wezterm.terminfo \
    && tic -x -o "$HOME/.terminfo" $tempfile \
    && rm $tempfile
fi
export TERM="wezterm"

# ########################
#
# ZSH
#
# ########################

# +------------+
# | NAVIGATION |
# +------------+

setopt AUTO_CD                   # Change to directory without cd
setopt AUTO_PUSHD                # Push the old directory onto the stack on cd
setopt PUSHD_IGNORE_DUPS         # Do not store duplicates in the stack
setopt PUSHD_SILENT              # Do not print the directory stack after pushd or popd

# +---------+
# | HISTORY |
# +---------+

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

alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index

# +-------------+
# | Completions |
# +-------------+

# Should be called before compinit
zmodload zsh/complist

# antidote
zsh_plugins=${XDG_CONFIG_HOME:-~/.config}/.zsh_plugins.zsh
antidote_path=$(brew --prefix)/opt/antidote/share/antidote
[[ -f ${zsh_plugins:r}.txt ]] || touch ${zsh_plugins:r}.txt
source $antidote_path/antidote.zsh
antidote load ${zsh_plugins:r}.txt

# zsh plugins configuration
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/opt/homebrew/share/zsh-syntax-highlighting/highlighters
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^[[A" history-beginning-search-backward-end
bindkey "^[[B" history-beginning-search-forward-end

autoload -U compinit; compinit
_comp_options+=(globdots) # With hidden files

setopt complete_in_word
setopt glob_dots            # show hidden files in completion
setopt MENU_COMPLETE        # Automatically highlight first element of completion menu
setopt AUTO_LIST            # Automatically list choices on ambiguous completion.
setopt COMPLETE_IN_WORD     # Complete from both ends of a word.

# +---------+
# | zstyles |
# +---------+

# Ztyle pattern
# :completion:<function>:<completer>:<command>:<argument>:<tag>

# Define completers
zstyle ':completion:*' completer _extensions _complete _approximate

# Complete the alias when _expand_alias is used as a function
zstyle ':completion:*' complete true

zle -C alias-expansion complete-word _generic
bindkey '^Xa' alias-expansion
zstyle ':completion:alias-expansion:*' completer _expand_alias

# Allow you to select in a menu
zstyle ':completion:*' menu select

zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:*:*:*:descriptions' format '%F{blue}-- %D %d --%f'
zstyle ':completion:*:*:*:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:*:*:*:warnings' format ' %F{red}-- no matches found --%f'

# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Only display some tags for the command cd
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories

# Required for completion to be in good groups (named after the tags)
zstyle ':completion:*' group-name ''
zstyle ':completion:*:*:-command-:*:*' group-order aliases builtins functions commands

# See ZSHCOMPWID "completion matching control"
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' keep-prefix true
zstyle -e ':completion:*:(ssh|scp|sftp|rsh|rsync):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'

# exclude .. and . from completion
# zstyle ':completion:*' special-dirs false

# fzf completions
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
zstyle ':fzf-tab:complete:tldr:argument-1' fzf-preview 'tldr --color always $word'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'

# hashicorp completion setup behind fn
hashi_comp() {
  complete -o nospace -C /opt/homebrew/bin/nomad nomad
  complete -o nospace -C /opt/homebrew/bin/terraform terraform
}

# ########################
#
# Path
#
# ########################

# make sure brew is in path !
eval "$(/opt/homebrew/bin/brew shellenv)"

# ########################
#
# Aliases
#
# ########################

# eza
if which eza > /dev/null 2>&1; then
    alias ls='eza -a -1'
    alias la='eza -1 --level=1 --tree --icons --classify --colour=auto --sort=name --group-directories-first --header --modified --created --git --binary -la'
    alias ll="eza -1 --level=2 --icons --tree --ignore-glob='target|node_modules|venv|env|.vscode|.DS_Store|.cache|__pycache__' --classify --colour=auto --sort=name --group-directories-first --header --modified --created --git --binary --group -la"
fi

# broot
if which broot > /dev/null 2>&1; then
    alias broot="broot -dsi"
fi

# gdu
if which gdu-go > /dev/null 2>&1; then
    alias gdu='gdu-go'
fi

# bat
if which bat > /dev/null 2>&1; then
    alias cat="bat"

    # help colorizer
    alias -g -- -h='-h 2>&1 | bat --language=help --style=plain'
    alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
fi

# +-----+
# | Git |
# +-----+

alias gs='git status'
alias gss='git status -s'
alias ga='git add'
alias gp='git push'
alias gpraise='git blame'
alias gpo='git push origin'
alias gpof='git push origin --force-with-lease'
alias gpofn='git push origin --force-with-lease --no-verify'
alias gpt='git push --tag'
alias gtd='git tag --delete'
alias gtdr='git tag --delete origin'
alias grb='git branch -r'                                                                           # display remote branch
alias gplo='git pull origin'
alias gb='git branch '
alias gc='git commit'
alias gd='git diff'
alias gco='git checkout '
alias gl='git log --pretty=oneline'
alias gr='git remote'
alias grs='git remote show'
alias glol='git log --graph --abbrev-commit --oneline --decorate'
alias gclean="git branch --merged | grep  -v '\\*\\|master\\|develop' | xargs -n 1 git branch -d" # Delete local branch merged with master
# git log for each branches
alias gblog="git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:red)%(refname:short)%(color:reset) - %(color:yellow)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:blue)%(committerdate:relative)%(color:reset))'"
alias gsub="git submodule update --remote"                                                        # pull submodules
alias gj="git-jump"                                                                               # Open in vim quickfix list files of interest (git diff, merged...)

alias dif="git diff --no-index"                                                                   # Diff two files even if not in git repo! Can add -w (don't diff whitespaces)

# ########################
#
# Application Setup & Fn Overrides
#
# ########################

# atuin
if which atuin > /dev/null 2>&1; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi

# broot => br
if which broot > /dev/null 2>&1; then
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
fi

# starship
if which starship > /dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# CD
if which zoxide > /dev/null 2>&1; then
    eval "$(zoxide init {{#if dotter.packages.zsh}}zsh{{else}}bash{{/if}})"
    cd ()
    {
        z "$@" || return $?
        ls
    }
fi


# fzf
if which fzf > /dev/null 2>&1; then
    j ()  # Navigate with fzf
    {
        # Settle for not hiding gitignored stuff
        find_command='find ~ -type d'

        if which fd > /dev/null 2>&1; then
            find_command='fd . ~ --type d'
        fi

        dir=$(eval $find_command | fzf --preview 'tree -CF -L 2 {+1}')
        fzf_return=$?
        [ $fzf_return = 0 ] && cd $dir || return $fzf_return
    }
fi

# Simple function to upgrade wezterm if on nightly
upgrade_wezterm()
{
  brew upgrade --cask wezterm-nightly --no-quarantine --greedy-latest
}

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

if [[ -f "$HOME/.zsh-extra" ]]; then
    source "$HOME/.zsh-extra"
fi
