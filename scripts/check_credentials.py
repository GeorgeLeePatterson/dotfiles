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


if __name__ == "__main__":
    unittest.main()
