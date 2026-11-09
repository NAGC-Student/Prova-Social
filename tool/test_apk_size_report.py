#!/usr/bin/env python3
"""Testa o relatório de tamanho dos APKs sem depender de um build real."""

from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

from apk_size_report import main, render_markdown, write_report

FIXED_TIME = datetime(2026, 11, 8, 12, 0, tzinfo=UTC)


class ApkSizeReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.input = self.root / "apks"
        self.input.mkdir()
        self.json_path = self.root / "out" / "apk-sizes.json"
        self.markdown_path = self.root / "out" / "apk-sizes.md"

    def _apk(self, name: str, content: bytes) -> Path:
        path = self.input / name
        path.write_bytes(content)
        return path

    def test_reports_each_apk_with_bytes_and_sha256(self) -> None:
        self._apk("app-arm64-v8a-release.apk", b"arm64-fake-apk")
        self._apk("app-armeabi-v7a-release.apk", b"armv7-fake-apk")
        self._apk("not-an-apk.txt", b"ignored")

        report = write_report(
            self.input, self.json_path, self.markdown_path, generated_at=FIXED_TIME
        )

        self.assertEqual(report["schema_version"], 1)
        self.assertEqual(report["generated_at"], "2026-11-08T12:00:00Z")
        self.assertEqual(
            [apk["name"] for apk in report["apks"]],
            ["app-arm64-v8a-release.apk", "app-armeabi-v7a-release.apk"],
        )
        self.assertEqual(report["apks"][0]["bytes"], len(b"arm64-fake-apk"))
        self.assertEqual(
            report["apks"][0]["sha256"],
            hashlib.sha256(b"arm64-fake-apk").hexdigest(),
        )
        self.assertEqual(
            report["total_bytes"],
            len(b"arm64-fake-apk") + len(b"armv7-fake-apk"),
        )

        saved = json.loads(self.json_path.read_text(encoding="utf-8"))
        self.assertEqual(saved, report)
        markdown = self.markdown_path.read_text(encoding="utf-8")
        self.assertIn("| app-arm64-v8a-release.apk | 14 |", markdown)
        self.assertIn(report["apks"][0]["sha256"], markdown)
        self.assertIn("**Total:** 28 B", markdown)
        self.assertNotIn("not-an-apk.txt", markdown)

    def test_markdown_contains_one_row_per_apk(self) -> None:
        apks = [
            {"name": "a.apk", "bytes": 1048576, "sha256": "a" * 64},
            {"name": "b.apk", "bytes": 524288, "sha256": "b" * 64},
        ]
        report = {
            "schema_version": 1,
            "generated_at": "2026-11-08T12:00:00Z",
            "total_bytes": 1572864,
            "apks": apks,
        }

        markdown = render_markdown(report)

        self.assertEqual(markdown.count("| a.apk |"), 1)
        self.assertEqual(markdown.count("| b.apk |"), 1)
        self.assertIn("1.00 MiB", markdown)
        self.assertIn("0.50 MiB", markdown)
        self.assertIn("(1.50 MiB)", markdown)

    def test_missing_directory_fails_with_message(self) -> None:
        missing = self.root / "missing"
        exit_code = main(
            [
                "--input",
                str(missing),
                "--json",
                str(self.json_path),
                "--markdown",
                str(self.markdown_path),
            ]
        )
        self.assertEqual(exit_code, 1)
        self.assertFalse(self.json_path.exists())

    def test_empty_directory_fails_without_writing_reports(self) -> None:
        exit_code = main(
            [
                "--input",
                str(self.input),
                "--json",
                str(self.json_path),
                "--markdown",
                str(self.markdown_path),
            ]
        )
        self.assertEqual(exit_code, 1)
        self.assertFalse(self.json_path.exists())
        self.assertFalse(self.markdown_path.exists())


if __name__ == "__main__":
    unittest.main()
