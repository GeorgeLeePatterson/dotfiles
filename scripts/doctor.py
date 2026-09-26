#!/usr/bin/env python3
"""Read-only workstation checks. Report names/presence, never credential values."""
import argparse
import importlib.util
import os
from pathlib import Path
import pwd
import re
import shutil
import socket
import subprocess

BASE = ["git", "gh", "aws", "delta", "git-lfs", "jq", "rg", "fd", "fzf", "eza",
        "bat", "tree", "broot", "btop", "micro", "just", "starship", "atuin", "zoxide",
        "node", "pnpm", "uv", "psql", "docker"]
APPS = ["Brave Browser", "Ghostty", "Slack", "Zed", "Claude", "Codex"]


def succeeds(command):
    try:
        return subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              timeout=8).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def app_path(name):
    return next((str(p) for p in [Path('/Applications') / (name + '.app'),
                                 Path.home() / 'Applications' / (name + '.app')] if p.is_dir()), None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apps', action='store_true')
    parser.add_argument('--dev', action='store_true')
    parser.add_argument('--project', type=Path, help='Check .npmrc references and container prerequisites')
    args = parser.parse_args()
    missing = []
    print(f"Machine: {socket.gethostname()} | account: {pwd.getpwuid(os.getuid()).pw_name}")
    print('Checks apply to this process/session; another account or SSH login may differ.')
    for command in BASE + (["tmux", "lazygit", "glow"] if args.dev else []):
        path = shutil.which(command)
        print(f"{'OK' if path else 'MISSING'} {command}: {path or 'run ./setup.sh' + (' --dev' if command in ['tmux', 'lazygit', 'glow'] else '')}")
        if not path:
            missing.append(command)
    for name in ['Docker'] + (APPS if args.apps else ['Brave Browser']):
        path = app_path(name)
        print(f"{'OK' if path else 'MISSING'} app {name}: {path or 'install with setup (--apps for optional apps)'}")
        if not path and (name == 'Docker' or args.apps):
            missing.append(name)
    for command in [['docker', 'compose', 'version'], ['docker', 'buildx', 'version']]:
        ok = succeeds(command)
        print(f"{'OK' if ok else 'MISSING'} {' '.join(command[:2])}")
        if not ok:
            missing.append(command[1])
    engine = succeeds(['docker', 'info', '--format', '{{.ServerVersion}}'])
    print('Docker engine: ' + ('reachable in current context' if engine else 'not reachable; open Docker Desktop when containers are needed'))
    for key in ['user.name', 'user.email']:
        print(f"Git {key}: " + ('configured' if succeeds(['git', 'config', '--global', '--includes', '--get', key]) else 'missing'))
    print('GitHub CLI login: ' + ('available' if succeeds(['gh', 'auth', 'status', '--hostname', 'github.com']) else 'needs sign-in or Keychain access in this session'))
    for relative in ['projects/georgeleepatterson', 'projects/ai', 'projects/packages']:
        print(f"{'OK' if (Path.home()/relative).is_dir() else 'MISSING'} ~/{relative}")
    spec = importlib.util.spec_from_file_location('credentials', Path(__file__).resolve().with_name('credentials.py'))
    credentials = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(credentials)
    try:
        print('Keychain: ' + ('unlocked' if credentials.keychain_status() & 1 else 'locked in this session; stored does not mean exported'))
        for group in credentials.EVERYDAY:
            for name in credentials.GROUPS[group]:
                print(f"{name}: stored={'yes' if credentials.present(name) else 'no'}, environment={'set' if os.environ.get(name) else 'unset'}")
    except (RuntimeError, OSError, subprocess.TimeoutExpired):
        print('Keychain: inaccessible; check from a terminal in the signed-in account')
    # Inspect shell assignments without evaluating or printing their contents.
    for relative in ['.zshrc.local', '.zshenv.local', '.zprofile.local', '.bash_profile', '.bashrc', '.profile']:
        path = Path.home() / relative
        if path.is_file():
            names = re.findall(r'^\s*(?:export\s+)?([A-Z][A-Z0-9_]*)=', path.read_text(), re.M)
            names = [n for n in names if re.search(r'TOKEN|SECRET|PASSWORD|ACCESS_KEY|API_KEY', n)]
            if names:
                print(f"REVIEW ~/{relative}: credential assignments {', '.join(sorted(set(names)))} (values hidden)")
    if args.project:
        project = args.project.expanduser().resolve()
        if not project.is_dir():
            parser.error('project must be an existing directory')
        print(f'Project: {project}')
        npmrc = project / '.npmrc'
        if npmrc.is_file():
            names = sorted(set(re.findall(r'\$\{([A-Z][A-Z0-9_]*)\}', npmrc.read_text())))
            for name in names:
                ok = bool(os.environ.get(name))
                print(f"{'OK' if ok else 'MISSING'} project environment {name}")
                if not ok:
                    missing.append(name)
            print('Presence does not verify registry permissions or token expiry.')
        if any((project / name).is_file() for name in ['compose.yml', 'compose.yaml', 'docker-compose.yml', 'docker-compose.yaml']):
            print('Project has Compose configuration. Start its database using the project documentation.')
            print('Dotfiles does not create databases, load .env files, or run production reads.')
    print('Result: ' + ('missing prerequisites: ' + ', '.join(missing) if missing else 'installed prerequisites found; account sign-ins and project services are separate'))
    return bool(missing)


if __name__ == '__main__':
    raise SystemExit(main())
