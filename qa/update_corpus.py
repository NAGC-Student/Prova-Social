#!/usr/bin/env python3
"""Incrementally fetch the QA corpus; existing bytes are never downloaded again."""
import hashlib
import json
import sys
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "qa" / "corpus_manifest.json"


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    corpus = ROOT / manifest["storage"]
    corpus.mkdir(parents=True, exist_ok=True)
    downloaded = 0
    skipped = 0
    pending = 0
    failed = 0
    records = []
    seen_hashes = {}

    def digest_and_validate_pdf(path: Path, item: dict) -> str:
        with path.open("rb") as source:
            if source.read(5) != b"%PDF-":
                raise ValueError(f"{item['id']} response is not a PDF")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        expected = item.get("sha256")
        if expected and digest != expected:
            raise ValueError(
                f"{item['id']} SHA-256 mismatch: expected {expected}, got {digest}"
            )
        return digest

    for item in manifest["documents"]:
        source_id = item.get("sourceId")
        if not source_id:
            board = item.get("board")
            if not isinstance(board, str) or not board.strip():
                raise ValueError(
                    f"{item['id']} needs sourceId or a non-empty board"
                )
            source_id = board.lower().replace(" ", "-")
        target = corpus / item["path"]
        url = item.get("downloadUrl")
        if not url:
            pending += 1
            print(f"PENDENTE {item['id']}: link direto ainda não cadastrado")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_file() and target.stat().st_size > 0:
            digest = digest_and_validate_pdf(target, item)
            skipped += 1
            print(f"OK      {item['id']} ({target.stat().st_size} bytes)")
        else:
            temporary = target.with_suffix(target.suffix + ".part")
            print(f"BAIXANDO {item['id']} <- {url}")
            request = urllib.request.Request(url, headers={"User-Agent": "Prova-Social QA corpus updater"})
            try:
                for attempt in range(1, 4):
                    try:
                        with urllib.request.urlopen(request, timeout=90) as response, temporary.open("wb") as output:
                            while chunk := response.read(1024 * 1024):
                                output.write(chunk)
                        digest = digest_and_validate_pdf(temporary, item)
                        temporary.replace(target)
                        downloaded += 1
                        break
                    except Exception as error:
                        if attempt == 3:
                            try:
                                subprocess.run(
                                    ["curl", "--fail", "--location", "--retry", "3", "--connect-timeout", "20", "-A", "Prova-Social QA corpus updater", "-o", str(temporary), url],
                                    check=True,
                                    timeout=180,
                                )
                                digest = digest_and_validate_pdf(temporary, item)
                                temporary.replace(target)
                                downloaded += 1
                                print(f"OK      {item['id']} (fallback curl)")
                            except Exception as fallback_error:
                                failed += 1
                                print(f"FALHOU  {item['id']}: {error}; fallback: {fallback_error}", file=sys.stderr)
                        else:
                            time.sleep(attempt)
            finally:
                if temporary.exists():
                    temporary.unlink()
        if target.is_file() and target.stat().st_size > 0:
            record = {
                "document_id": item["id"],
                "source_id": source_id,
                "banca": item.get("board"),
                "board": item.get("board"),
                "institution": item.get("institution"),
                "title": item["exam"],
                "url": item["sourceUrl"],
                "direct_url": url,
                "source_kind": item.get("sourceKind"),
                "sha256": digest,
                "size_bytes": target.stat().st_size, "content_type": "application/pdf",
                "local_path": target.relative_to(corpus).as_posix(),
                "document_type": item.get("documentType", "prova"),
                "related_document_id": item.get("relatedDocumentId"),
                "year": item["year"],
                "status": "downloaded",
                "expected_question_count": item.get("expectedQuestionCount"),
                "minimum_question_count": item.get("minQuestions"),
                "expected_count_source": item.get("expectedCountSource"),
                "expected_answer_count": item.get("expectedAnswerCount"),
                "expected_answer_question_numbers": item.get(
                    "expectedAnswerQuestionNumbers"
                ),
                "metadata_ground_truth": item.get("metadataGroundTruth"),
                "license_status": item.get("licenseStatus", "public_download"),
                "redistribution": item.get("redistribution", "not_allowed"),
            }
            duplicate_of = seen_hashes.get(digest)
            if duplicate_of is not None:
                record["status"] = "duplicate"
                record["duplicate_of"] = duplicate_of
            else:
                seen_hashes[digest] = item["id"]
            records.append(record)
    manifest_path = corpus / "datasets" / "manifests" / "documents.jsonl"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        "".join(json.dumps(record, ensure_ascii=False) + "\n" for record in records),
        encoding="utf-8",
    )
    print(f"Concluído: {downloaded} novos, {skipped} já existentes, {pending} pendentes, {failed} falhas.")
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Falha ao atualizar corpus: {error}", file=sys.stderr)
        raise
