# Explicit macOS Keychain helpers. No secrets are read until you call one.
keycheck() {
  command dotfiles-credentials status
}

keyload() {
  emulate -L zsh
  local names name value
  local -A pending
  names=$(command dotfiles-credentials names "${1:-}") || return $?
  for name in ${(f)names}; do
    if ! value=$(security find-generic-password -a "$USER" -s "$name" -w 2>/dev/null); then
      print -u2 "keyload: '$name' is missing or inaccessible; no variables were changed"
      return 1
    fi
    pending[$name]=$value
  done
  # The old Docker password export was an alias of this same token.
  [[ $1 == docker ]] && pending[DOCKER_HUB_PASSWORD]=${pending[DOCKER_TOKEN]}
  for name in ${(k)pending}; do export "$name=${pending[$name]}"; done
  print "Loaded $1 into this shell"
}

keyset() {
  emulate -L zsh
  local service="$1" val="${2:-}"
  if [[ -z "$service" ]]; then
    print -u2 "usage: keyset <name> [value]   (omit value to be prompted silently)"
    return 1
  fi
  if [[ -z "$val" ]]; then
    printf "Value for %s: " "$service"
    IFS= read -rs val
    print
  fi
  [[ -z "$val" ]] && { print -u2 "keyset: empty value, aborting"; return 1; }
  security add-generic-password -a "$USER" -s "$service" -w "$val" \
    -j "shell-env" -l "shell-env: $service" -U \
    && print "✓ stored $service in login keychain"
}

keyenv() {
  emulate -L zsh
  local var="$1" service="${2:-$1}"
  local val
  if ! val="$(security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null)"; then
    print -u2 "keyenv: '$service' not found in keychain (add it with: keyset $service)"
    return 1
  fi
  export "$var=$val"
}

keyget() {
  security find-generic-password -a "$USER" -s "$1" -w
}

keydel() {
  security delete-generic-password -a "$USER" -s "$1" >/dev/null \
    && print "✓ deleted $1 from login keychain"
}

keylist() {
  security dump-keychain 2>/dev/null | perl -ne '
    if (/^keychain:/) {
      print "$svc\n" if $shell_env && $svc;
      $svc = ""; $shell_env = 0;
    }
    $svc = $1 if /"svce"<blob>="([^"]*)"/;
    $shell_env = 1 if /"icmt"<blob>="shell-env"/;
    END { print "$svc\n" if $shell_env && $svc; }
  ' | sort -u
}
