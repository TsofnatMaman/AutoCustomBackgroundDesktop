"""Regression tests for SEC-01 (GitHub branch-name command injection)."""

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from sync_repo_metadata import powershell_literal, sync_metadata  # noqa: E402


class MetadataSecurityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "Src").mkdir()
        (self.root / "Src" / "config.json").write_text(
            '{"github":{"username":"old","repository":"old","branch":"main",'
            '"imagePath":"backgrounds/1.jpg"},"wallpaper":{"text":"test"}}\n',
            encoding="utf-8-sig",
        )
        (self.root / "Src" / "install.ps1").write_text(
            '$githubUsername = "old"\n$githubRepoName = "old"\n'
            '$githubBranchName = "main"\nWrite-Output "other statements unchanged"\n',
            encoding="utf-8-sig",
        )

    def test_normal_fork_branch(self):
        result = sync_metadata(self.root, "ExampleOwner/wallpaper-fork", "feat/new-event")
        self.assertEqual(result, (True, True))
        config = json.loads((self.root / "Src" / "config.json").read_text(encoding="utf-8-sig"))
        self.assertEqual(config["github"]["branch"], "feat/new-event")
        self.assertEqual(config["github"]["username"], "ExampleOwner")
        self.assertEqual(config["github"]["imagePath"], "backgrounds/1.jpg")
        install = (self.root / "Src" / "install.ps1").read_text(encoding="utf-8-sig")
        self.assertIn("$githubBranchName = 'feat/new-event'", install)
        self.assertIn('Write-Output "other statements unchanged"', install)
        self.assertEqual(sync_metadata(self.root, "ExampleOwner/wallpaper-fork", "feat/new-event"), (False, False))

    def test_powershell_metacharacters_stay_literal(self):
        branch = 'feat/a\';$(Write-Output INJECTED);#"'
        sync_metadata(self.root, "ExampleOwner/wallpaper-fork", branch)
        actual = (self.root / "Src" / "install.ps1").read_text(encoding="utf-8-sig")
        self.assertIn("$githubBranchName = " + powershell_literal(branch) + "\n", actual)
        self.assertEqual(actual.count("$githubBranchName = "), 1)
        self.assertEqual(json.loads((self.root / "Src" / "config.json").read_text(encoding="utf-8-sig"))["github"]["branch"], branch)
        self.assertEqual(sync_metadata(self.root, "ExampleOwner/wallpaper-fork", branch), (False, False))

    def test_bom_preserved(self):
        sync_metadata(self.root, "A/B", "foo")
        for name in ("config.json", "install.ps1"):
            self.assertTrue((self.root / "Src" / name).read_bytes().startswith(b"\xef\xbb\xbf"))

    def test_invalid_metadata_rejected_before_file_changes(self):
        original = (self.root / "Src" / "config.json").read_bytes()
        with self.assertRaises(ValueError):
            sync_metadata(self.root, "not-owner-repo", "main")
        self.assertEqual((self.root / "Src" / "config.json").read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
