#!/usr/bin/env python3
"""Check that normalized prova documents use the right gabarito variant."""
import json
import sys
from collections import defaultdict
from pathlib import Path


def validate(root: Path) -> list[str]:
    docs = []
    for path in sorted((root / "datasets" / "normalized" / "auto").glob("*.json")):
        try:
            docs.append(json.loads(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            continue
    groups = defaultdict(list)
    for doc in docs:
        group = doc.get("metadata", {}).get("group_id")
        if group:
            groups[group].append(doc)
    errors = []
    checked = 0
    for group, members in groups.items():
        keys = [d for d in members if d.get("metadata", {}).get("document_type") == "gabarito" and d.get("answer_keys")]
        if not keys:
            continue
        for proof in [d for d in members if d.get("metadata", {}).get("document_type") == "prova"]:
            questions = {q.get("number") for q in proof.get("questions", [])}
            if not questions:
                # Discursive/practical booklets can legitimately have no
                # objective question numbers even when the source publishes a
                # generic answer sheet in the same group.
                continue
            associated = [k for k in proof.get("answer_keys", []) if k.get("method") == "associated"]
            if not associated:
                errors.append(f"{proof.get('document_id')}: nenhuma chave associada no grupo {group}")
                continue
            checked += 1
            for key in associated:
                entries = key.get("entries", [])
                numbers = [entry.get("question_number") for entry in entries if not entry.get("annulled")]
                if len(numbers) != len(set(numbers)):
                    errors.append(f"{proof.get('document_id')}: gabarito associado tem questões repetidas")
                overlap = set(numbers) & questions
                if not overlap:
                    errors.append(f"{proof.get('document_id')}: gabarito não coincide com números da prova")
                if any(entry.get("answer") not in {"A", "B", "C", "D", "E", None} for entry in entries):
                    errors.append(f"{proof.get('document_id')}: gabarito tem resposta fora de A-E")
    print(f"provas com vínculo verificável: {checked}")
    return errors


if __name__ == "__main__":
    corpus = Path(sys.argv[1] if len(sys.argv) > 1 else "/home/nikolas/Corpus/prova-social-corpus")
    errors = validate(corpus)
    for error in errors:
        print(f"ERRO {error}", file=sys.stderr)
    raise SystemExit(1 if errors else 0)
