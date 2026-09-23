#!/usr/bin/env python3
"""Small macOS shell-credential inventory, migration and direct SSH transfer.

Values never go to stdout, command arguments, Git, or a transfer file.
The only retained plaintext files are private backups of files being cleaned.
"""
import argparse
import ctypes
import getpass
import json
import os
from pathlib import Path
import pwd
import re
import select
import shlex
import subprocess
import sys
import tempfile
import time
import warnings

GROUPS = {
    "huggingface": ["HF_TOKEN"],
    "npm": ["NPM_TOKEN"],
    "docker": ["DOCKER_HUB_USERNAME", "DOCKER_TOKEN"],
    "github-pat": ["GITHUB_PERSONAL_ACCESS_TOKEN"],
}
ARCHIVED = ["GH_TOKEN", "AWS_ACCESS_KEY_ID", "AWS_SESSION_TOKEN", "NPM_TOKEN_LEGACY_BASH"]
KNOWN = {name for names in GROUPS.values() for name in names} | set(ARCHIVED)
OLD_REFERENCES = {"DOCKER_HUB_PASSWORD": "DOCKER_TOKEN", "GITHUB_PERSONAL_ACCESS_TOKEN": "GH_TOKEN"}
ACCOUNT = pwd.getpwuid(os.getuid()).pw_name
HOME = Path.home()


def keychain_status():
    """Read the default file Keychain's state without prompting or reading items."""
    api = ctypes.CDLL("/System/Library/Frameworks/Security.framework/Security")
    core = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    api.SecKeychainCopyDefault.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
    api.SecKeychainCopyDefault.restype = ctypes.c_int32
    api.SecKeychainGetStatus.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
    api.SecKeychainGetStatus.restype = ctypes.c_int32
    core.CFRelease.argtypes = [ctypes.c_void_p]
    core.CFRelease.restype = None
    keychain, flags = ctypes.c_void_p(), ctypes.c_uint32()
    code = api.SecKeychainCopyDefault(ctypes.byref(keychain))
    if code or not keychain.value:
        raise RuntimeError("No accessible default Keychain; finish this Mac's account setup first.")
    try:
        code = api.SecKeychainGetStatus(keychain, ctypes.byref(flags))
        if code:
            raise RuntimeError(f"Cannot inspect the default Keychain (macOS status {code}).")
        return flags.value
    finally:
        core.CFRelease(keychain)


def require_keychain_ready(write=False):
    flags = keychain_status()
    # Apple's SecKeychainStatus: unlocked=1, readable=2, writable=4.
    if not flags & 1:
        raise RuntimeError("Keychain is locked in this session. Use security unlock-keychain in an interactive terminal.")
    if not flags & 2 or (write and not flags & 4):
        raise RuntimeError("Keychain access is restricted in this session; check its permissions before retrying.")


def unlock_keychain(password):
    """Unlock only this process's default Keychain; never pass a password in argv."""
    if not isinstance(password, str) or not password or "\0" in password:
        raise RuntimeError("A nonempty Keychain password is required.")
    api = ctypes.CDLL("/System/Library/Frameworks/Security.framework/Security")
    api.SecKeychainUnlock.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_ubyte]
    api.SecKeychainUnlock.restype = ctypes.c_int32
    encoded = password.encode()
    buffer = ctypes.create_string_buffer(encoded)
    try:
        code = api.SecKeychainUnlock(None, len(encoded), buffer, 1)
    finally:
        ctypes.memset(buffer, 0, len(buffer))
    if code:
        raise RuntimeError(f"Keychain unlock failed (macOS status {code}); no credentials were imported.")


def security_error(result, operation):
    # Raw stderr can contain command input. Classify only known errors; never
    # include it in a diagnostic (including hex-encoded credential values).
    if b"User interaction is not allowed" in result.stderr or b"-25308" in result.stderr:
        return RuntimeError(f"Keychain {operation} needs an interactive unlock or access approval on this Mac (macOS -25308).")
    return RuntimeError(f"Keychain {operation} failed (exit {result.returncode}); no credential values were printed.")


def security(*args, read=False):
    result = subprocess.run(["/usr/bin/security", *args], capture_output=True, timeout=120)
    if result.returncode == 44:
        return None
    if result.returncode:
        raise security_error(result, "access")
    if read:
        # security adds one newline, independently of the stored value.
        return result.stdout.removesuffix(b"\n").decode("utf-8")
    return True


def present(name):
    return security("find-generic-password", "-a", ACCOUNT, "-s", name) is not None


def read_value(name):
    return security("find-generic-password", "-a", ACCOUNT, "-s", name, "-w", read=True)


def store(name, value):
    if name not in KNOWN or not isinstance(value, str) or not value or "\0" in value:
        raise RuntimeError("Invalid credential entry; nothing was printed.")
    current = read_value(name)
    if current is not None:
        if current != value:
            raise RuntimeError(f"{name}: an existing different value was preserved.")
        return
    # security's interactive input avoids exposing a value in argv. Hex avoids
    # its command parser's quoting ambiguities; the pipe is private, not encrypted.
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", ACCOUNT):
        raise RuntimeError("Unsupported account short name.")
    command = (f"add-generic-password -a {ACCOUNT} -s {name} -j shell-env "
               f"-l shell-env:{name} -X {value.encode().hex()}\n")
    result = subprocess.run(["/usr/bin/security", "-i"], input=command.encode(),
                            capture_output=True, timeout=120)
    if result.returncode:
        raise security_error(result, f"write for {name}")
    if read_value(name) != value:
        raise RuntimeError(f"{name}: Keychain read-back did not match; inspect this item before retrying.")


def names_for(groups):
    return list(dict.fromkeys(name for group in groups for name in GROUPS[group]))


def import_values(values):
    require_keychain_ready(write=True)
    if not isinstance(values, dict) or not values or any(
        name not in KNOWN or not isinstance(value, str) or not value or "\0" in value
        for name, value in values.items()
    ):
        raise RuntimeError("Invalid import.")
    # Detect all existing conflicts before writing any entries. Repeating after
    # interruption is safe: identical entries are retained, never overwritten.
    for name, value in values.items():
        existing = read_value(name)
        if existing is not None and existing != value:
            raise RuntimeError(f"{name}: target already has a different value; import stopped.")
    for name, value in values.items():
        store(name, value)
        print(f"{name}: stored/verified", flush=True)


def literal_assignment(line, names):
    match = re.match(r"^\s*(?:export\s+)?([A-Z][A-Z0-9_]*)=(.*)$", line)
    if not match or match[1] not in names:
        return None
    raw = match[2].strip()
    # Parse literal assignments only. Never execute old shell configuration.
    if ("$" in raw or "`" in raw) and not (raw.startswith("'") and raw.endswith("'")):
        raise RuntimeError(f"{match[1]}: expression requires manual migration.")
    tokens = shlex.split(raw, comments=True)
    if len(tokens) != 1 or not tokens[0]:
        raise RuntimeError(f"{match[1]}: expected a nonempty literal assignment.")
    return match[1], tokens[0]


def migrate():
    edits, values = {}, {}
    for relative in [".zshrc.local", ".bash_profile"]:
        path = HOME / relative
        if not path.is_file():
            continue
        if path.is_symlink():
            raise RuntimeError(f"~/{relative} is a symlink; inspect it before migrating.")
        original = path.read_text()
        lines = []
        for line in original.splitlines(keepends=True):
            reference = re.fullmatch(r"\s*export\s+([A-Z_]+)=\$([A-Z_]+)\s*", line)
            if reference and reference[1] in OLD_REFERENCES:
                if reference[2] != OLD_REFERENCES[reference[1]] or not present(reference[2]):
                    raise RuntimeError(f"{reference[1]}: unresolved legacy reference; source preserved.")
                print(f"{reference[1]} referenced {reference[2]}; existing Keychain item retained.")
                continue
            parsed = literal_assignment(line, KNOWN)
            if parsed:
                name, value = parsed
                if relative == ".bash_profile" and name == "NPM_TOKEN":
                    existing = read_value(name)
                    if existing is not None and existing != value:
                        name = "NPM_TOKEN_LEGACY_BASH"
                if name in values and values[name] != value:
                    raise RuntimeError(f"{name}: conflicting source values; sources unchanged.")
                values[name] = value
                continue
            if relative == ".zshrc.local":
                lookup = re.fullmatch(r"\s*keyenv\s+([A-Z][A-Z0-9_]*)\s*", line)
                if lookup and lookup[1] in KNOWN:
                    continue
                setting = literal_assignment(line, {"RUST_BACKTRACE", "AWS_DEFAULT_REGION"})
                if setting and setting in [("RUST_BACKTRACE", "full"), ("AWS_DEFAULT_REGION", "us-east-1")]:
                    continue
            lines.append(line)
        cleaned = "".join(lines)
        if cleaned != original:
            if relative == ".zshrc.local":
                # Keep actual local aliases/completion, discard now-empty headings.
                cleaned = "\n".join(line for line in cleaned.splitlines()
                                    if line.strip() and not line.lstrip().startswith("#")) + "\n"
                cleaned = ("# Local overrides only. Credentials live in macOS Keychain.\n"
                           "# Inspect: keycheck. Load when needed: keyload <group>.\n" + cleaned)
            edits[path] = (original, cleaned)
    if not edits:
        print("No legacy shell credential assignments remain in the migration inputs.")
        return
    if values:
        import_values(values)
    backup_root = HOME / ".local/state/dotfiles/credential-backups"
    backup_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = Path(tempfile.mkdtemp(prefix="migration-", dir=backup_root))
    for path, (original, cleaned) in edits.items():
        if path.read_text() != original:
            raise RuntimeError("A source file changed during migration; re-run after reviewing it.")
        saved = backup / path.name
        saved.write_text(original)
        saved.chmod(0o600)
        fd, staged = tempfile.mkstemp(prefix=".credentials-", dir=path.parent)
        try:
            with os.fdopen(fd, "w") as stream:
                stream.write(cleaned)
            os.replace(staged, path)
        finally:
            if os.path.exists(staged):
                os.unlink(staged)
        print(f"Cleaned ~/{path.name}")
    print(f"Private rollback copies: {backup}")
    print("Use a fresh terminal; already-running processes retain their old environment.")


def receive():
    # Unlock and import must run in the SAME SSH security session. A separate
    # `ssh security unlock-keychain` does not unlock later SSH connections.
    if not keychain_status() & 1:
        print("DOTFILES_UNLOCK_V1", flush=True)
        raw = sys.stdin.buffer.readline(8193)
        if len(raw) > 8192 or not raw.endswith(b"\n"):
            raise RuntimeError("Invalid unlock request.")
        password = json.loads(raw)
        del raw
        unlock_keychain(password)
        del password
    require_keychain_ready(write=True)
    print("DOTFILES_READY_V1", flush=True)
    read_import()


def read_import():
    raw = sys.stdin.buffer.read(65537)
    if len(raw) > 65536:
        raise RuntimeError("Import exceeds size limit.")
    import_values(json.loads(raw))


def read_reply(stream, timeout=120):
    """Bound both waiting and output size before trusting a protocol reply."""
    deadline, reply = time.monotonic() + timeout, bytearray()
    while len(reply) < 128:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([stream], [], [], remaining)[0]:
            raise RuntimeError("Target readiness timed out; no credentials were sent.")
        chunk = os.read(stream.fileno(), 1)
        if not chunk:
            raise RuntimeError("Target stopped before import; no credentials were sent. Check the error above.")
        reply.extend(chunk)
        if chunk == b"\n":
            return bytes(reply)
    raise RuntimeError("Unexpected target response; update dotfiles on both Macs before retrying.")


def transfer(host, groups):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+@[A-Za-z0-9][A-Za-z0-9.-]*", host):
        raise RuntimeError("Use account@hostname or account@IPv4-address.")
    require_keychain_ready()
    ssh = ["/usr/bin/ssh", "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", host,
           "~/.local/bin/dotfiles-credentials receive"]
    with subprocess.Popen(ssh, stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0) as process:
        try:
            reply = read_reply(process.stdout)
            if reply == b"DOTFILES_UNLOCK_V1\n":
                if not sys.stdin.isatty():
                    raise RuntimeError("Target Keychain needs its password. Run this transfer from your interactive terminal.")
                # A local hidden prompt; the password travels only inside SSH's
                # encrypted stdin and is used by Apple's API in the receiver.
                with warnings.catch_warnings():
                    warnings.simplefilter("error", getpass.GetPassWarning)
                    password = getpass.getpass(f"Keychain password for {host} (hidden; not saved): ")
                process.stdin.write(json.dumps(password).encode() + b"\n")
                process.stdin.flush()
                del password
                reply = read_reply(process.stdout)
            if reply != b"DOTFILES_READY_V1\n":
                raise RuntimeError("Unexpected target response; update dotfiles on both Macs before retrying.")
            values = {}
            for name in names_for(groups):
                value = read_value(name)
                if value is None:
                    raise RuntimeError(f"{name} is missing here; transfer has not started.")
                values[name] = value
            output, _ = process.communicate(json.dumps(values).encode(), timeout=300)
            # The receiver reports names/status only, never values or passwords.
            print(output.decode(), end="")
            if process.returncode:
                raise RuntimeError("Transfer incomplete. Inspect target Keychain access, then retry the same groups.")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="List groups and item presence, never values")
    commands.add_parser("check", help="Check Keychain readiness without reading credentials")
    commands.add_parser("migrate", help="Move old shell literals into Keychain and remove automatic exports")
    commands.add_parser("import", help=argparse.SUPPRESS)
    commands.add_parser("receive", help=argparse.SUPPRESS)
    names = commands.add_parser("names", help="Print variable names for a group")
    names.add_argument("group", choices=GROUPS)
    send = commands.add_parser("transfer", help="Transfer selected groups over SSH to another configured Mac")
    send.add_argument("host")
    send.add_argument("groups", choices=GROUPS, nargs="+")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise RuntimeError("This helper currently supports macOS Keychain only.")
    os.umask(0o077)
    if args.command == "status":
        print("Keychain: " + ("unlocked" if keychain_status() & 1 else "locked (item metadata only)"))
        for group, names in [*GROUPS.items(), ("retained, not auto-loaded or transferred", ARCHIVED)]:
            print(group + ":")
            for name in names:
                print(f"  {name}: {'present' if present(name) else 'not stored'}")
    elif args.command == "check":
        require_keychain_ready(write=True)
        print("Keychain is unlocked and writable in this session.")
    elif args.command == "names":
        print("\n".join(GROUPS[args.group]))
    elif args.command == "migrate":
        migrate()
    elif args.command == "import":
        read_import()
    elif args.command == "receive":
        receive()
    else:
        transfer(args.host, args.groups)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, EOFError, getpass.GetPassWarning, subprocess.TimeoutExpired):
        # Exception strings from libraries may contain input; only our deliberate
        # errors are shown. Never print subprocess stderr or import contents.
        error = sys.exc_info()[1]
        print(str(error) if isinstance(error, RuntimeError) else
              "Credential operation failed; original data was not intentionally deleted.", file=sys.stderr)
        sys.exit(1)
