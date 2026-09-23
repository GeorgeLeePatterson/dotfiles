# macOS Keychain helpers. Everyday groups load at interactive terminal startup.
keycheck() {
  command dotfiles-credentials status
}

keyload() {
  emulate -L zsh
  local names name value automatic=0
  if [[ $1 == --automatic ]]; then automatic=1; shift; fi
  local -A pending
  names=$(command dotfiles-credentials names "${1:-}") || return $?
  for name in ${(f)names}; do
    # Preserve deliberate overrides and avoid re-reading inherited credentials.
    if (( automatic && ${+parameters[$name]} )); then
      pending[$name]=${(P)name}
      continue
    fi
    if ! value=$(security find-generic-password -a "$USER" -s "$name" -w 2>/dev/null); then
      print -u2 "keyload: '$name' is missing or inaccessible; no variables were changed"
      return 1
    fi
    pending[$name]=$value
  done
  # The old Docker password export was an alias of this same token.
  if [[ $1 == docker ]]; then
    if (( automatic && ${+DOCKER_HUB_PASSWORD} )); then
      pending[DOCKER_HUB_PASSWORD]=$DOCKER_HUB_PASSWORD
    else
      pending[DOCKER_HUB_PASSWORD]=${pending[DOCKER_TOKEN]}
    fi
  fi
  for name in ${(k)pending}; do export "$name=${pending[$name]}"; done
  print "Loaded $1 into this shell"
}

keyautoload() {
  emulate -L zsh
  [[ ${DOTFILES_KEYCHAIN_AUTOLOAD:-1} == 0 ]] && return 0
  # Do not open password dialogs in a locked SSH session. A fresh installation
  # may not have any of these entries yet, so missing groups are quiet too.
  command dotfiles-credentials check >/dev/null 2>&1 || return 0
  local group
  for group in huggingface npm docker; do
    keyload --automatic "$group" >/dev/null 2>&1
  done
  return 0
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
