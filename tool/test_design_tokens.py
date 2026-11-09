#!/usr/bin/env python3
"""Garante que tamanhos de fonte fiquem centralizados em AppTypography."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
THEME = LIB / "core" / "theme" / "app_theme.dart"
LITERAL_FONT_SIZE = re.compile(r"fontSize:\s*(?:const\s*)?\d")


def main() -> int:
    violations: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        if path == THEME:
            continue
        for number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if LITERAL_FONT_SIZE.search(line):
                violations.append(
                    f"{path.relative_to(ROOT)}:{number}: {line.strip()}"
                )

    if violations:
        print("Tamanhos de fonte literais fora de AppTypography:")
        for violation in violations:
            print(f"- {violation}")
        return 1

    print("Nenhum fontSize literal fora de AppTypography.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
