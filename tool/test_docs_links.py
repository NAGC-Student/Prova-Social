#!/usr/bin/env python3
"""Valida a hierarquia documental e os links do repositório.

Não depende de pacotes externos. Verifica:
- links Markdown relativos;
- wikilinks do vault;
- numeração duplicada de seções no AGENTS.md;
- banner obrigatório nos documentos históricos.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".dart_tool", "build", "node_modules", ".obsidian"}
HISTORICAL_BANNER = "Documento histórico — congelado em 2026-11-07."
AGENTS = ROOT / "AGENTS.md"
HISTORICO = ROOT / "docs" / "historico"

LINK_RE = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)]+)\)")
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
FENCE_RE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")


def markdown_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*.md"):
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        files.append(path)
    return sorted(files)


def strip_code(text: str) -> str:
    return INLINE_CODE_RE.sub("", FENCE_RE.sub("", text))


def check_relative_link(source: Path, target: str) -> str | None:
    raw = target.strip().strip("<>")
    if not raw or raw.startswith(("#", "/", "http://", "https://", "mailto:")):
        return None
    if "{" in raw or "}" in raw:
        return None
    raw = raw.split("#", 1)[0].split("?", 1)[0]
    if not raw:
        return None
    candidate = (source.parent / unquote(raw)).resolve()
    if candidate.exists():
        return None
    return f"{source.relative_to(ROOT)}: link relativo quebrado: {target}"


def check_wikilink(source: Path, target: str) -> str | None:
    # Obsidian accepts "|" and the escaped form "\|" as the alias separator.
    raw = re.split(r"\\?\|", target, maxsplit=1)[0].split("#", 1)[0].strip()
    if not raw:
        return None
    base = ROOT / "knowledge-base"
    candidates = [
        (source.parent / raw).resolve(),
        (source.parent / f"{raw}.md").resolve(),
        (base / raw).resolve(),
        (base / f"{raw}.md").resolve(),
    ]
    if any(candidate.exists() for candidate in candidates):
        return None
    # Obsidian also resolves a bare note name anywhere in the vault.
    wanted = Path(raw).name
    if wanted.endswith(".md"):
        wanted = wanted[:-3]
    for candidate in base.rglob("*.md"):
        if candidate.stem == wanted:
            return None
    return f"{source.relative_to(ROOT)}: wikilink quebrado: [[{target}]]"


def main() -> int:
    errors: list[str] = []
    rel_links = 0
    wikilinks = 0

    agents_text = AGENTS.read_text(encoding="utf-8")
    numbers = [int(number) for number in re.findall(r"(?m)^## (\d+)\.", agents_text)]
    duplicates = sorted({number for number in numbers if numbers.count(number) > 1})
    if duplicates:
        errors.append(f"AGENTS.md: seções numeradas duplicadas: {duplicates}")

    for path in sorted(HISTORICO.glob("*.md")):
        if not path.read_text(encoding="utf-8").startswith("> **" + HISTORICAL_BANNER):
            errors.append(f"{path.relative_to(ROOT)}: banner histórico ausente")

    for path in markdown_files():
        text = strip_code(path.read_text(encoding="utf-8"))
        for match in LINK_RE.finditer(text):
            rel_links += 1
            error = check_relative_link(path, match.group(2))
            if error:
                errors.append(error)
        for match in WIKILINK_RE.finditer(text):
            wikilinks += 1
            error = check_wikilink(path, match.group(1))
            if error:
                errors.append(error)

    print(f"Arquivos Markdown: {len(markdown_files())}")
    print(f"Links relativos verificados: {rel_links}")
    print(f"Wikilinks verificados: {wikilinks}")
    if errors:
        print(f"\n{len(errors)} problema(s):")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Nenhum problema de documentação encontrado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
