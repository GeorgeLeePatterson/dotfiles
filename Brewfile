# Daily terminal tools. Re-running setup installs missing packages, without upgrades.
brew "git"
brew "gh"
brew "awscli"
brew "libpq" # psql/pg_dump clients; no database service is started
# Docker is baseline. Preserve an app installed manually instead of adopting it.
unless File.directory?("/Applications/Docker.app") || File.directory?(File.expand_path("~/Applications/Docker.app"))
  cask "docker-desktop"
end
brew "git-delta"
brew "git-lfs"
brew "jq"
brew "ripgrep"
brew "fd"
brew "fzf"
brew "eza"
brew "bat"
brew "tree"
brew "broot"
brew "btop"
brew "micro"
brew "just"
brew "starship"
brew "atuin"
brew "zoxide"

# Shell features, installed by Homebrew; no plugin manager or downloaded shell code.
brew "zsh-completions"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"
brew "fzf-tab"

# JavaScript and Python. setup.sh installs NVM from its official release.
brew "pnpm"
brew "uv"

# The prompt uses Nerd Font symbols. Ghostty itself is installed separately.
# Also accept an existing manual font installation; avoid Homebrew file collisions.
unless File.exist?(File.expand_path("~/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf")) ||
       File.exist?("/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf")
  cask "font-jetbrains-mono-nerd-font"
end
