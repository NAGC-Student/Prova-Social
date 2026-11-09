#!/usr/bin/env python3
"""Gera um relatório de tamanho e integridade dos APKs de uma release.

Recebe o diretório produzido por `flutter build apk --split-per-abi` e grava:

- JSON legível por máquina (`build/apk-sizes.json`);
- Markdown para o corpo da release (`build/apk-sizes.md`).

O tamanho registrado é o do arquivo comprimido, exatamente o que o usuário
baixa. O SHA-256 permite conferir que o APK anexado é o mesmo que foi medido.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

SCHEMA_VERSION = 1
READ_CHUNK = 1024 * 1024


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(READ_CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect_apks(directory: Path) -> list[dict[str, object]]:
    apks = sorted(path for path in directory.glob("*.apk") if path.is_file())
    if not apks:
        raise ValueError(f"Nenhum APK encontrado em {directory}")
    return [
        {
            "name": path.name,
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
        for path in apks
    ]


def build_report(
    apks: list[dict[str, object]], generated_at: datetime
) -> dict[str, object]:
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at.astimezone(UTC).isoformat().replace("+00:00", "Z"),
        "total_bytes": sum(int(apk["bytes"]) for apk in apks),
        "apks": apks,
    }


def _mib(value: int) -> str:
    return f"{value / (1024 * 1024):.2f} MiB"


def render_markdown(report: dict[str, object]) -> str:
    apks = report["apks"]
    assert isinstance(apks, list)
    lines = [
        "## Tamanho dos APKs",
        "",
        "Arquivos comprimidos como publicados. O SHA-256 permite conferir o",
        "download contra o binário medido.",
        "",
        "| APK | Bytes | Tamanho | SHA-256 |",
        "| --- | ---: | ---: | --- |",
    ]
    for apk in apks:
        assert isinstance(apk, dict)
        lines.append(
            "| {name} | {bytes} | {size} | `{sha256}` |".format(
                name=apk["name"],
                bytes=apk["bytes"],
                size=_mib(int(apk["bytes"])),
                sha256=apk["sha256"],
            )
        )
    lines.extend(
        [
            "",
            f"**Total:** {report['total_bytes']} B "
            f"({_mib(int(report['total_bytes']))}).",
            "",
        ]
    )
    return "\n".join(lines)


def write_report(
    input_dir: Path,
    json_path: Path,
    markdown_path: Path,
    generated_at: datetime | None = None,
) -> dict[str, object]:
    apks = collect_apks(input_dir)
    report = build_report(apks, generated_at or datetime.now(UTC))
    json_path.parent.mkdir(parents=True, exist_ok=True)
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    markdown_path.write_text(render_markdown(report), encoding="utf-8")
    return report


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera JSON e Markdown com tamanho e SHA-256 dos APKs."
    )
    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Diretório que contém os APKs compilados.",
    )
    parser.add_argument(
        "--json",
        type=Path,
        default=Path("build/apk-sizes.json"),
        help="Destino do relatório JSON.",
    )
    parser.add_argument(
        "--markdown",
        type=Path,
        default=Path("build/apk-sizes.md"),
        help="Destino do relatório Markdown.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if not args.input.is_dir():
        print(f"Diretório de APKs não encontrado: {args.input}", file=sys.stderr)
        return 1
    try:
        report = write_report(args.input, args.json, args.markdown)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    print(
        f"{len(report['apks'])} APK(s), {report['total_bytes']} bytes. "
        f"Relatórios: {args.json}, {args.markdown}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
