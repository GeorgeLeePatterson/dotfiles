alias d='dirs -v'
for index in {1..9}; do alias "$index"="cd +$index"; done
unset index
if (( $+commands[eza] )); then
  alias ls='eza -a -1'
  alias la='eza --tree --level=1 --icons --classify --group-directories-first --header --modified --created --git --binary -la'
  alias li="eza --tree --level=2 --icons --ignore-glob='target|node_modules|venv|env|.vscode|.DS_Store|.cache|__pycache__' --classify --group-directories-first --header --modified --created --git --binary --group -la"
  alias ll="eza --tree --level=2 --icons --ignore-glob='venv|env|.venv|.vscode|.DS_Store|.cache|__pycache__' --classify --group-directories-first --header --modified --created --git --binary --group -la"
fi
(( $+commands[bat] )) && alias cat=bat
(( $+commands[gdu-go] )) && alias gdu=gdu-go
alias gs='git status' gss='git status -s' ga='git add' gp='git push'
alias gpo='git push origin' gpof='git push origin --force-with-lease'
alias gb='git branch' gc='git commit' gd='git diff' gco='git checkout'
alias gplo='git pull origin' grb='git branch -r' gr='git remote' grs='git remote show'
alias gl='git log --pretty=oneline' glol='git log --graph --abbrev-commit --oneline --decorate'
alias gpraise='git blame' gsstat='git diff --shortstat' gnstat='git diff --numstat'
alias gpt='git push --tags' gtd='git tag --delete' gsub='git submodule update --remote'
alias dif='git diff --no-index'
if (( $+commands[broot] )); then
  br() {
    local cmd_file=$(mktemp) result
    command broot --outcmd "$cmd_file" "$@"
    result=$?
    if (( result == 0 )); then eval "$(<"$cmd_file")"; result=$?; fi
    command rm -f "$cmd_file"
    return $result
  }
fi
if (( $+commands[fzf] && $+commands[fd] )); then
  j() {
    [[ -t 0 && -t 1 ]] || { print -u2 'j requires an interactive terminal'; return 1; }
    local destination
    destination=$(fd --type d --hidden --exclude .git . "$HOME" | fzf --preview 'tree -C -L 2 {}') || return $?
    [[ -n $destination ]] && cd -- "$destination"
  }
fi
