#!/usr/bin/env python3
"""Disposable-home checks; never reads or writes a real credential store."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
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
        with patch.object(credentials.subprocess, "run") as run:
            run.return_value.returncode = 0
            credentials.transfer("farself@192.168.1.98", ["huggingface"])
            args, kwargs = run.call_args
            self.assertNotIn("private-test-value", repr(args))
            self.assertEqual(kwargs["input"], b'{"HF_TOKEN": "private-test-value"}')
            self.assertIn("StrictHostKeyChecking=yes", args[0])
        with self.assertRaises(RuntimeError):
            credentials.transfer("-bad-host", ["huggingface"])


if __name__ == "__main__":
    unittest.main()
