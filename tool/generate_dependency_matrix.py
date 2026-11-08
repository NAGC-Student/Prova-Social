#!/usr/bin/env python3
"""Gera a matriz de dependências a partir de pubspec.lock (ADR-0009)."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOCK = ROOT / "pubspec.lock"
DEFAULT_OUTPUT = ROOT / "knowledge-base" / "05 - Qualidade" / "Matriz de dependências.md"
POLICY_NOTE = "../03 - Domínios/Dependências e pins"

SECTION_RE = re.compile(r"^([a-z]+):[ \t]*$", re.MULTILINE)
PACKAGE_RE = re.compile(r"^  ([A-Za-z0-9_]+):\n((?: {4,}[^\n]*\n)*)", re.MULTILINE)
FIELD_RE = r"^    {0}: (.+)$"
DESCRIPTION_RE = r"^      {0}: (.+)$"
SDK_RE = re.compile(r"^  (dart|flutter): (.+)$", re.MULTILINE)

FRONTMATTER = """---
tipo: area
area: dependências e manutenção
status: VALIDADO
classificacao: MANTER
nivel: {{correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}}
fonte_codigo: [pubspec.lock, tool/generate_dependency_matrix.py]
sha: {lock_sha}
confianca: alta
atualizado: {updated}
---"""


class LockError(ValueError):
    """O lock não tem a estrutura que o gerador sabe ler."""


def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def _section(text: str, name: str) -> str:
    start = None
    for match in SECTION_RE.finditer(text):
        if match.group(1) == name:
            start = match.end()
        elif start is not None:
            return text[start : match.start()]
    if start is None:
        raise LockError(f"Seção '{name}:' ausente no lock.")
    return text[start:]


def _field(block: str, pattern: str, name: str, package: str) -> str:
    match = re.search(pattern.format(re.escape(name)), block, re.MULTILINE)
    if match is None:
        raise LockError(f"Pacote '{package}' sem campo '{name}' no lock.")
    return _unquote(match.group(1))


def parse_lock(text: str) -> tuple[list[dict[str, str]], dict[str, str]]:
    packages_text = _section(text, "packages")
    if not packages_text.endswith("\n"):
        packages_text += "\n"
    packages: list[dict[str, str]] = []
    consumed = []
    for match in PACKAGE_RE.finditer(packages_text):
        name, block = match.group(1), match.group(2)
        consumed.append(match.group(0))
        source = _field(block, FIELD_RE, "source", name)
        origin = source
        if source == "path":
            origin = f"path: {_field(block, DESCRIPTION_RE, 'path', name)}"
        elif source == "sdk":
            origin = f"sdk: {_field(block, FIELD_RE, 'description', name)}"
        packages.append(
            {
                "name": name,
                "dependency": _field(block, FIELD_RE, "dependency", name),
                "version": _field(block, FIELD_RE, "version", name),
                "origin": origin,
            }
        )
    if "".join(consumed).strip() != packages_text.strip():
        raise LockError("Estrutura de 'packages:' não reconhecida; gerador recusou o lock.")
    if not packages:
        raise LockError("Nenhum pacote resolvido em 'packages:'.")
    names = [package["name"] for package in packages]
    if len(set(names)) != len(names):
        raise LockError("Pacote repetido em 'packages:'.")
    sdks = {
        match.group(1): _unquote(match.group(2))
        for match in SDK_RE.finditer(_section(text, "sdks"))
    }
    return packages, sdks


def _table(packages: list[dict[str, str]]) -> list[str]:
    lines = ["| Pacote | Versão resolvida | Origem |", "|---|---|---|"]
    for package in sorted(packages, key=lambda item: item["name"]):
        lines.append(
            f"| `{package['name']}` | `{package['version']}` | {package['origin']} |"
        )
    return lines


def render(lock_bytes: bytes, previous: str | None, today: str) -> str:
    lock_sha = hashlib.sha256(lock_bytes).hexdigest()
    packages, sdks = parse_lock(lock_bytes.decode("utf-8"))
    updated = today
    if previous is not None:
        old_sha = re.search(r"(?m)^sha: (.+)$", previous)
        old_date = re.search(r"(?m)^atualizado: (.+)$", previous)
        if old_sha and old_date and old_sha.group(1).strip() == lock_sha:
            updated = old_date.group(1).strip()

    main = [p for p in packages if p["dependency"] == "direct main"]
    dev = [p for p in packages if p["dependency"] == "direct dev"]
    transitive = [p for p in packages if p["dependency"] == "transitive"]
    known = {"direct main", "direct dev", "transitive"}
    other = [p for p in packages if p["dependency"] not in known]

    lines = [
        FRONTMATTER.format(lock_sha=lock_sha, updated=updated),
        "",
        "# Matriz de dependências (gerada do lock)",
        "",
        "> Gerada por `tool/generate_dependency_matrix.py` a partir de `pubspec.lock`.",
        "> Não editar à mão: `python3 tool/generate_dependency_matrix.py --check` falha",
        "> se o texto divergir do lock. Regra de pin e cadência de atualização:",
        f"> [[{POLICY_NOTE}|Dependências e pins]].",
        "",
        f"- **SHA-256 de `pubspec.lock`:** `{lock_sha}`",
        f"- **Data desta matriz:** {updated} — mantida enquanto o SHA-256 não muda,",
        "  para que a nota não envelheça sozinha nem passe no `--check` por sorte.",
        f"- **Pacotes resolvidos:** {len(packages)} — {len(main)} diretos de app,",
        f"  {len(dev)} diretos de dev, {len(transitive)} transitivos"
        + (f", {len(other)} de outro tipo" if other else "")
        + ".",
        "- `nivel` zerado e `classificacao: MANTER`: é inventário gerado, não auditoria",
        "  de área. Nesta nota o campo `sha:` do frontmatter é o SHA-256 do lock, não",
        "  um commit — a fonte medida é o conteúdo do arquivo, não um snapshot do repo.",
        "- O lock Dart não cobre os artefatos Gradle do plugin PaddleOCR; eles estão",
        "  em `packages/paddleocr_android/android/build.gradle` e no aviso de terceiros.",
        "",
        "## Diretas de app",
        "",
        *_table(main),
        "",
        "## Diretas de dev",
        "",
        *_table(dev),
        "",
    ]
    if other:
        lines += ["## Outras dependências declaradas", "", *_table(other), ""]
    lines += [
        "## Transitivas",
        "",
        *_table(transitive),
        "",
        "## SDKs",
        "",
        "| SDK | Constraint resolvida |",
        "|---|---|",
    ]
    for name in sorted(sdks):
        lines.append(f"| `{name}` | `{sdks[name]}` |")
    lines += [
        "",
        "## Como regenerar",
        "",
        "```sh",
        "python3 tool/generate_dependency_matrix.py",
        "python3 tool/generate_dependency_matrix.py --check",
        "```",
        "",
        "O `--check` roda no `qa/run_static.sh`. A matriz só muda quando o lock muda:",
        "aceitar PR do dependabot exige regenerar a nota no mesmo commit.",
        "",
    ]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--check",
        action="store_true",
        help="falha se a matriz gravada estiver diferente da que o lock produz",
    )
    args = parser.parse_args(argv)

    try:
        lock_bytes = args.lock.read_bytes()
    except OSError as error:
        print(f"Falha ao ler {args.lock}: {error}", file=sys.stderr)
        return 1
    previous = None
    if args.output.exists():
        previous = args.output.read_text(encoding="utf-8")
    try:
        expected = render(lock_bytes, previous, date.today().isoformat())
    except (LockError, UnicodeDecodeError) as error:
        print(f"Falha ao interpretar o lock: {error}", file=sys.stderr)
        return 1

    if args.check:
        if previous is None:
            print(f"Matriz ausente: {args.output}", file=sys.stderr)
            return 1
        if previous != expected:
            print(
                f"Matriz desatualizada: {args.output}\n"
                "Rode: python3 tool/generate_dependency_matrix.py",
                file=sys.stderr,
            )
            return 1
        print(f"Matriz de dependências confere com {args.lock}.")
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    packages, _ = parse_lock(lock_bytes.decode("utf-8"))
    print(f"Matriz gerada em {args.output} ({len(packages)} pacotes).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())