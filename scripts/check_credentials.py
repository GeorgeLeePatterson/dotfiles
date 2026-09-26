#!/usr/bin/env python3
"""Disposable-home checks; never reads or writes a real credential store."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("credentials", Path(__file__).with_name("credentials.py"))
credentials = importlib.util.module_from_spec(spec)
spec.loader.exec_module(credentials)


class CredentialsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.values = {"NPM_TOKEN": "current-test-value"}
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(credentials, "HOME", self.home))
        self.stack.enter_context(patch.object(credentials, "read_value", side_effect=self.values.get))
        self.stack.enter_context(patch.object(credentials, "present", side_effect=lambda name: name in self.values))
        self.stack.enter_context(patch.object(credentials, "store", side_effect=self.values.__setitem__))
        self.stack.enter_context(patch.object(credentials, "require_keychain_ready"))
        self.output = self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))

    def test_migration_and_repeat_preserve_values_and_local_settings(self):
        source = "export HF_TOKEN='test-hf-value'\nkeyenv GH_TOKEN\nalias mine='pwd'\n"
        (self.home / ".zshrc.local").write_text(source)
        (self.home / ".bash_profile").write_text("export NPM_TOKEN='old-test-value'\nexport PATH=/tmp/bin:$PATH\n")
        credentials.migrate()
        self.assertEqual(self.values["HF_TOKEN"], "test-hf-value")
        self.assertEqual(self.values["NPM_TOKEN"], "current-test-value")
        self.assertEqual(self.values["NPM_TOKEN_LEGACY_BASH"], "old-test-value")
        self.assertIn("alias mine='pwd'", (self.home / ".zshrc.local").read_text())
        self.assertNotIn("keyenv", (self.home / ".zshrc.local").read_text())
        self.assertNotIn("NPM_TOKEN", (self.home / ".bash_profile").read_text())
        copies = list(self.home.glob(".local/state/dotfiles/credential-backups/*/.zshrc.local"))
        self.assertEqual(len(copies), 1)
        self.assertEqual(copies[0].read_text(), source)
        self.assertEqual(copies[0].stat().st_mode & 0o777, 0o600)
        credentials.migrate()
        self.assertEqual(len(list(self.home.glob(".local/state/dotfiles/credential-backups/*"))), 1)
        self.assertNotIn("test-hf-value", self.output.getvalue())

    def test_existing_different_credential_stops_before_source_cleanup(self):
        source = "export NPM_TOKEN='conflicting-value'\nexport HF_TOKEN='another-value'\n"
        path = self.home / ".zshrc.local"
        path.write_text(source)
        with self.assertRaises(RuntimeError):
            credentials.migrate()
        self.assertEqual(path.read_text(), source)
        self.assertNotIn("HF_TOKEN", self.values)

    def test_expressions_are_not_executed(self):
        with self.assertRaises(RuntimeError):
            credentials.literal_assignment("export HF_TOKEN=$(touch /tmp/do-not-create)", {"HF_TOKEN"})

    def test_legacy_alias_does_not_create_duplicate_secrets(self):
        self.values["DOCKER_TOKEN"] = "existing-test-token"
        (self.home / ".zshrc.local").write_text("export DOCKER_HUB_PASSWORD=$DOCKER_TOKEN\n")
        credentials.migrate()
        self.assertEqual(self.values["DOCKER_TOKEN"], "existing-test-token")
        self.assertNotIn("DOCKER_HUB_PASSWORD", self.values)

    def test_bad_import_is_rejected_before_changes(self):
        with self.assertRaises(RuntimeError):
            credentials.import_values({"HF_TOKEN": "valid-test-value", "UNKNOWN": "bad"})
        self.assertNotIn("HF_TOKEN", self.values)

    def test_transfer_keeps_values_off_argv_and_excludes_archived_items(self):
        self.values["HF_TOKEN"] = "private-test-value"
        with patch.object(credentials.subprocess, "Popen") as popen, patch.object(credentials, "read_reply", return_value=b"DOTFILES_READY_V1\n"):
            process = popen.return_value.__enter__.return_value
            process.communicate.return_value = (b"HF_TOKEN: stored/verified\n", None)
            process.returncode = 0
            credentials.transfer("farself@192.168.1.98", ["huggingface"])
            args, kwargs = popen.call_args
            self.assertNotIn("private-test-value", repr(args))
            self.assertEqual(process.communicate.call_args.args[0], b'{"HF_TOKEN": "private-test-value"}')
            self.assertIn("StrictHostKeyChecking=yes", args[0])
            popen.assert_called_once()
        with self.assertRaises(RuntimeError):
            credentials.transfer("-bad-host", ["huggingface"])

    def test_locked_target_stops_before_source_read_or_payload(self):
        with patch.object(credentials.subprocess, "Popen") as popen, patch.object(credentials, "read_reply", return_value=b"DOTFILES_UNLOCK_V1\n"), patch.object(credentials.sys.stdin, "isatty", return_value=False):
            with self.assertRaisesRegex(RuntimeError, "interactive terminal"):
                credentials.transfer("farself@192.168.1.98", ["huggingface"])
            credentials.read_value.assert_not_called()
            process = popen.return_value.__enter__.return_value
            process.stdin.write.assert_not_called()
            process.communicate.assert_not_called()

    def test_unlock_and_import_use_one_connection_and_wait_for_ready(self):
        self.values["HF_TOKEN"] = "private-test-value"
        with patch.object(credentials.subprocess, "Popen") as popen, patch.object(credentials, "read_reply", side_effect=[b"DOTFILES_UNLOCK_V1\n", b"DOTFILES_READY_V1\n"]), patch.object(credentials.sys.stdin, "isatty", return_value=True), patch.object(credentials.getpass, "getpass", return_value="synthetic-password"):
            process = popen.return_value.__enter__.return_value
            process.communicate.return_value = (b"HF_TOKEN: stored/verified\n", None)
            process.returncode = 0
            credentials.transfer("farself@192.168.1.98", ["huggingface"])
            popen.assert_called_once()
            process.stdin.write.assert_called_once_with(b'"synthetic-password"\n')
            self.assertNotIn("synthetic-password", repr(popen.call_args))
            self.assertNotIn("synthetic-password", self.output.getvalue())

    def test_failed_unlock_never_reads_source_tokens(self):
        with patch.object(credentials.subprocess, "Popen"), patch.object(credentials, "read_reply", side_effect=[b"DOTFILES_UNLOCK_V1\n", RuntimeError("Unlock failed")]), patch.object(credentials.sys.stdin, "isatty", return_value=True), patch.object(credentials.getpass, "getpass", return_value="synthetic-password"):
            with self.assertRaisesRegex(RuntimeError, "Unlock failed"):
                credentials.transfer("farself@192.168.1.98", ["huggingface"])
            credentials.read_value.assert_not_called()

    def test_receiver_unlocks_before_reading_or_storing_payload(self):
        wire = b'"synthetic-password"\n{"HF_TOKEN":"synthetic-token"}'
        with patch.object(credentials, "keychain_status", return_value=2), patch.object(credentials, "unlock_keychain") as unlock, patch.object(credentials.sys, "stdin", io.TextIOWrapper(io.BytesIO(wire))):
            credentials.receive()
            unlock.assert_called_once_with("synthetic-password")
            self.assertEqual(self.values["HF_TOKEN"], "synthetic-token")
            self.assertEqual(self.output.getvalue().splitlines(), ["DOTFILES_UNLOCK_V1", "DOTFILES_READY_V1", "HF_TOKEN: stored/verified"])

    def test_real_pipe_handshake_and_import(self):
        self.values["HF_TOKEN"] = "private-test-value"
        receiver = '''import json, sys
print("DOTFILES_UNLOCK_V1", flush=True)
assert json.loads(sys.stdin.buffer.readline()) == "synthetic-password"
print("DOTFILES_READY_V1", flush=True)
assert json.loads(sys.stdin.buffer.read()) == {"HF_TOKEN": "private-test-value"}
print("HF_TOKEN: stored/verified", flush=True)
'''
        real_popen = subprocess.Popen
        with patch.object(credentials.subprocess, "Popen", side_effect=lambda *args, **kwargs: real_popen([sys.executable, "-c", receiver], **kwargs)) as popen, patch.object(credentials.sys.stdin, "isatty", return_value=True), patch.object(credentials.getpass, "getpass", return_value="synthetic-password"):
            credentials.transfer("farself@192.168.1.98", ["huggingface"])
            popen.assert_called_once()
            self.assertEqual(self.output.getvalue(), "HF_TOKEN: stored/verified\n")


class KeychainDiagnosticsTests(unittest.TestCase):
    def test_no_response_times_out(self):
        read_fd, write_fd = os.pipe()
        try:
            with os.fdopen(read_fd, "rb", buffering=0) as stream:
                with self.assertRaisesRegex(RuntimeError, "timed out"):
                    credentials.read_reply(stream, timeout=0.01)
        finally:
            os.close(write_fd)

    def test_invalid_or_missing_password_is_rejected(self):
        for password in [None, "", "bad\0value"]:
            with self.assertRaises(RuntimeError):
                credentials.unlock_keychain(password)

    def test_locked_state_fails_without_reading_items(self):
        with patch.object(credentials, "keychain_status", return_value=2):
            with self.assertRaisesRegex(RuntimeError, "locked in this session"):
                credentials.require_keychain_ready(write=True)

    def test_error_is_actionable_without_echoing_command_input(self):
        value = "synthetic-private-value"
        result = subprocess.CompletedProcess([], 36, b"", b"User interaction is not allowed " + value.encode().hex().encode())
        with patch.object(credentials, "read_value", return_value=None), patch.object(credentials.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(RuntimeError, "interactive unlock") as error:
                credentials.store("HF_TOKEN", value)
            self.assertNotIn(value, str(error.exception))
            self.assertNotIn(value.encode().hex(), str(error.exception))


class ShellAutoloadTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.home = Path(directory.name)
        self.calls = self.home / "calls"
        self.env = {"HOME": str(self.home), "USER": "fixture", "PATH": f"{self.home}:/usr/bin:/bin",
                    "TEST_CALLS": str(self.calls),
                    "SHELL_HELPER": str(Path(__file__).resolve().parent.parent / "zsh/keychain.zsh")}
        helper = self.home / "dotfiles-credentials"
        helper.write_text("#!/usr/bin/python3\n" + '''import importlib.util, os
from pathlib import Path
spec = importlib.util.spec_from_file_location("credentials", os.environ["CREDENTIALS_SOURCE"])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def ready(*args, **kwargs):
    if os.environ.get("TEST_LOCKED") == "1": raise RuntimeError("locked")
def read(name):
    with open(os.environ["TEST_CALLS"], "a") as f: print(name, file=f)
    return None if name == os.environ.get("TEST_MISSING") else "synthetic-" + name
m.require_keychain_ready = ready
m.read_value = read
m.main()
''')
        helper.chmod(0o700)
        self.env["CREDENTIALS_SOURCE"] = str(Path(__file__).with_name("credentials.py").resolve())

    def run_shell(self, checks, **env):
        result = subprocess.run(["/bin/zsh", "-dfc", 'source "$SHELL_HELPER"; keyautoload; ' + checks],
                                env={**self.env, **env}, capture_output=True)
        self.assertEqual(result.returncode, 0, "Shell assertions failed")
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"")

    def test_everyday_groups_load_quietly_and_nested_load_reuses_values(self):
        self.run_shell('''[[ $HF_TOKEN == synthetic-HF_TOKEN && $NPM_TOKEN == synthetic-NPM_TOKEN ]] || exit 1
[[ $DOCKER_HUB_USERNAME == synthetic-DOCKER_HUB_USERNAME && $DOCKER_TOKEN == synthetic-DOCKER_TOKEN ]] || exit 1
[[ $DOCKER_HUB_PASSWORD == $DOCKER_TOKEN ]] || exit 1
[[ -z ${GH_TOKEN+x} && -z ${AWS_SESSION_TOKEN+x} && -z ${GITHUB_PERSONAL_ACCESS_TOKEN+x} ]] || exit 1
keyautoload''')
        self.assertEqual(len(self.calls.read_text().splitlines()), 4)

    def test_existing_overrides_are_preserved(self):
        self.run_shell('[[ $HF_TOKEN == override && $DOCKER_HUB_PASSWORD == explicit ]]',
                       HF_TOKEN="override", DOCKER_HUB_PASSWORD="explicit")
        self.assertNotIn("HF_TOKEN", self.calls.read_text())

    def test_missing_group_does_not_export_half_a_group(self):
        self.run_shell('[[ -n $HF_TOKEN && -z ${DOCKER_TOKEN+x} && -z ${DOCKER_HUB_USERNAME+x} ]]',
                       TEST_MISSING="DOCKER_TOKEN")

    def test_locked_keychain_and_opt_out_do_not_read_items(self):
        for env in [{"TEST_LOCKED": "1"}, {"DOTFILES_KEYCHAIN_AUTOLOAD": "0"}]:
            self.run_shell('[[ -z ${HF_TOKEN+x} && -z ${DOCKER_TOKEN+x} ]]', **env)
            self.assertFalse(self.calls.exists())

    def test_noninteractive_startup_loads_without_terminal_or_parent_exports(self):
        (self.home / ".zshenv").symlink_to(Path(__file__).resolve().parent.parent / "zsh/zshenv")
        result = subprocess.run(["/bin/zsh", "-c", '[[ $NPM_TOKEN == synthetic-NPM_TOKEN && $HF_TOKEN == synthetic-HF_TOKEN ]]'],
                                env=self.env, capture_output=True)
        self.assertEqual(result.returncode, 0, "Noninteractive startup must load credentials")
        self.assertEqual(result.stdout + result.stderr, b"")


class CredentialEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.dict(os.environ, {}, clear=True))
        self.stack.enter_context(patch.object(credentials, "require_keychain_ready"))
        self.reader = self.stack.enter_context(patch.object(credentials, "read_value", side_effect=lambda n: "synthetic-" + n))

    def test_run_limits_exports_and_preserves_existing_values(self):
        with patch.dict(os.environ, {"NPM_TOKEN": "override"}), patch.object(credentials.os, "execvpe") as execute:
            credentials.run_with_credentials("npm", ["--", "pnpm", "install"])
            execute.assert_called_once_with("pnpm", ["pnpm", "install"], {"NPM_TOKEN": "override"})
            self.reader.assert_not_called()

    def test_locked_run_fails_before_exec(self):
        with patch.object(credentials, "require_keychain_ready", side_effect=RuntimeError("locked")), patch.object(credentials.os, "execvpe") as execute:
            with self.assertRaisesRegex(RuntimeError, "locked"):
                credentials.run_with_credentials("npm", ["pnpm", "install"])
            execute.assert_not_called()
            self.reader.assert_not_called()

    def test_shell_protocol_quotes_secret_as_data(self):
        value = "synthetic-'$(exit 91)\n; false"
        with patch.object(credentials, "read_value", return_value=value), patch.object(credentials.sys.stdout, "isatty", return_value=False):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                credentials.shell_environment()
        # Capture synthetic exports; never run this test against a real Keychain.
        code = output.getvalue() + "\n[[ $NPM_TOKEN == $EXPECTED ]]"
        result = subprocess.run(["/bin/zsh", "-dfc", code], env={"EXPECTED": value}, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout + result.stderr, b"")

    def test_terminal_display_is_rejected(self):
        with patch.object(credentials.sys.stdout, "isatty", return_value=True):
            with self.assertRaisesRegex(RuntimeError, "terminal display"):
                credentials.shell_environment()
        self.reader.assert_not_called()

    def test_empty_inherited_token_is_filled_and_archived_tokens_excluded(self):
        with patch.dict(os.environ, {"NPM_TOKEN": ""}):
            values = credentials.environment_for(credentials.EVERYDAY)
        self.assertEqual(values["NPM_TOKEN"], "synthetic-NPM_TOKEN")
        self.assertFalse(set(credentials.ARCHIVED) & values.keys())


if __name__ == "__main__":
    unittest.main()
