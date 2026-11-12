#!/usr/bin/env python3
"""Utilitário de registro de atividades para o dashboard de acompanhamento.

Atualiza scripts/dashboard/session.json de forma atômica e preserva o histórico
entre sessões, permitindo que outro agente continue o trabalho.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
STATE_FILE = BASE_DIR / "session.json"
AGENT = os.environ.get("DASHBOARD_AGENT", "kilo")

PHASES = {
    "analisando": "Analisando",
    "implementando": "Implementando",
    "testando": "Testando",
    "corrigindo": "Corrigindo",
    "bloqueado": "Bloqueado",
    "concluido": "Concluído",
    "aguardando": "Aguardando",
}

FILE_BUCKETS = ("analyzed", "modified", "created", "pending_review", "problems")
TEST_STATES = ("nao_executado", "executando", "aprovado", "reprovado", "ignorado")
PROBLEM_TYPES = (
    "bug", "compilacao", "falha_teste", "arquitetura",
    "dependencia", "bloqueio_ambiental",
)
PROBLEM_STATUSES = ("aberto", "resolvido", "bloqueado")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_state() -> dict:
    if STATE_FILE.exists():
        try:
            with STATE_FILE.open("r", encoding="utf-8") as fh:
                data = json.load(fh)
            if isinstance(data, dict):
                return data
        except (json.JSONDecodeError, OSError):
            pass
    return blank_state()


def blank_state() -> dict:
    return {
        "meta": {
            "project": "Prova Social",
            "dashboard_version": "1.0.0",
            "agent": AGENT,
            "current_session_id": None,
            "sessions": [],
        },
        "state": {
            "phase": "aguardando",
            "overall": "aguardando",
            "progress": 0,
            "elapsed_seconds": 0,
            "last_activity": "Nenhuma atividade registrada ainda.",
            "last_update": None,
            "started_at": None,
            "main_task": None,
        },
        "current_activity": {
            "what": None,
            "file": None,
            "region": None,
            "function": None,
            "objective": None,
            "last_action": None,
            "next_action": None,
            "started_at": None,
            "position_known": False,
        },
        "steps": [],
        "files": {
            "analyzed": [],
            "modified": [],
            "created": [],
            "pending_review": [],
            "problems": [],
        },
        "tests": {
            "executed": 0,
            "running": 0,
            "passed": 0,
            "failed": 0,
            "skipped": 0,
            "total": 0,
            "duration_seconds": 0,
            "command": None,
            "last_result": None,
            "last_run": None,
            "errors": [],
            "cases": [],
        },
        "problems": [],
        "history": [],
    }


def atomic_write(data: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        dir=str(STATE_FILE.parent), prefix=".session.", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        os.replace(tmp_path, STATE_FILE)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def save_state(data: dict) -> None:
    data["meta"]["agent"] = AGENT
    data["state"]["last_update"] = now_iso()
    atomic_write(data)


def cmd_init(args: argparse.Namespace) -> int:
    data = load_state()
    sessions = data.setdefault("meta", {}).setdefault("sessions", [])
    prev_id = data["meta"].get("current_session_id")
    if prev_id:
        sessions = [
            s
            for s in sessions
            if not (isinstance(s, dict) and s.get("id") == prev_id)
        ]
        sessions.append(
            {
                "id": prev_id,
                "agent": data["meta"].get("agent", AGENT),
                "started_at": data["state"].get("started_at"),
                "ended_at": now_iso(),
                "main_task": data["state"].get("main_task"),
                "phase": data["state"].get("phase"),
            }
        )
        data["meta"]["sessions"] = sessions

    session_id = f"sess_{uuid.uuid4().hex[:12]}"
    started = now_iso()
    data["meta"]["current_session_id"] = session_id

    # Preserve accumulated arrays across sessions; reset mutable run state.
    accumulated = {
        "files": data.get("files"),
        "tests": data.get("tests"),
        "problems": data.get("problems"),
        "history": data.get("history"),
        "steps": data.get("steps", []),
    }
    data = blank_state()
    data["meta"]["current_session_id"] = session_id
    data["meta"]["sessions"] = sessions
    data["meta"]["agent"] = AGENT
    data["state"]["started_at"] = started
    data["state"]["main_task"] = args.task or "Sessão sem tarefa definida"
    data["state"]["phase"] = "analisando"
    data["state"]["overall"] = "analisando"
    data["state"]["progress"] = 0
    data["state"]["last_activity"] = "Sessão iniciada."
    data["current_activity"] = {
        "what": "Inicialização da sessão",
        "file": None,
        "region": None,
        "function": None,
        "objective": args.task,
        "last_action": "Sessão iniciada via dashboard record init",
        "next_action": "Definir primeira etapa de trabalho",
        "started_at": started,
        "position_known": False,
    }
    for key, value in accumulated.items():
        if isinstance(value, list):
            data[key] = value
    _append_history(data, "sessao_iniciada", args.task or "Sessão iniciada.")
    save_state(data)
    print(f"Sessão iniciada: {session_id}")
    return 0


def cmd_set(args: argparse.Namespace) -> int:
    data = load_state()
    st = data["state"]
    if args.phase:
        if args.phase not in PHASES:
            print(f"Fase inválida: {args.phase}. Use: {', '.join(PHASES)}", file=sys.stderr)
            return 2
        st["phase"] = args.phase
        st["overall"] = args.phase
    if args.status:
        st["overall"] = args.status
    if args.progress is not None:
        st["progress"] = max(0, min(100, int(args.progress)))
    if args.main_task:
        st["main_task"] = args.main_task
    if args.last_activity:
        st["last_activity"] = args.last_activity
    save_state(data)
    print("Estado atualizado.")
    return 0


def cmd_activity(args: argparse.Namespace) -> int:
    data = load_state()
    ca = data["current_activity"]
    ca["what"] = args.what if args.what is not None else ca.get("what")
    ca["file"] = args.file if args.file is not None else ca.get("file")
    ca["region"] = args.region if args.region is not None else ca.get("region")
    ca["function"] = args.function if args.function is not None else ca.get("function")
    ca["objective"] = args.objective if args.objective is not None else ca.get("objective")
    ca["last_action"] = args.last_action if args.last_action is not None else ca.get("last_action")
    ca["next_action"] = args.next_action if args.next_action is not None else ca.get("next_action")
    if args.start:
        ca["started_at"] = now_iso()
    if args.position_known is not None:
        ca["position_known"] = args.position_known
    st = data["state"]
    st["last_activity"] = args.what
    save_state(data)
    print("Atividade atual registrada.")
    return 0


def _find(items: list, key: str, value) -> int | None:
    for i, item in enumerate(items):
        if isinstance(item, dict) and item.get(key) == value:
            return i
    return None


def cmd_step(args: argparse.Namespace) -> int:
    data = load_state()
    steps = data.setdefault("steps", [])
    step = {
        "id": args.id,
        "name": args.name,
        "state": args.state,
        "started_at": args.started_at or None,
        "finished_at": args.finished_at or None,
        "description": args.description or "",
        "result": args.result or "",
    }
    idx = _find(steps, "id", args.id)
    if idx is None:
        steps.append(step)
    else:
        steps[idx] = step
    st = data["state"]
    st["last_activity"] = f"Etapa '{args.name}' -> {args.state}"
    save_state(data)
    print(f"Etapa registrada: {args.id} ({args.state})")
    return 0


def cmd_file(args: argparse.Namespace) -> int:
    data = load_state()
    bucket = args.kind
    if bucket not in FILE_BUCKETS:
        print(f"Bucket inválido: {bucket}. Use: {', '.join(FILE_BUCKETS)}", file=sys.stderr)
        return 2
    files = data.setdefault("files", {})
    arr = files.setdefault(bucket, [])
    entry = {
        "path": args.path,
        "last_activity": args.note or now_iso(),
        "note": args.note or "",
        "registered_at": now_iso(),
    }
    idx = _find(arr, "path", args.path)
    if idx is None:
        arr.append(entry)
    else:
        arr[idx] = entry
    st = data["state"]
    st["last_activity"] = f"Arquivo {bucket}: {args.path}"
    save_state(data)
    print(f"Arquivo registrado ({bucket}): {args.path}")
    return 0


def cmd_test(args: argparse.Namespace) -> int:
    data = load_state()
    tests = data.setdefault("tests", {})
    cases = tests.setdefault("cases", [])
    state = args.state
    if state not in TEST_STATES:
        print(f"Estado de teste inválido: {state}. Use: {', '.join(TEST_STATES)}", file=sys.stderr)
        return 2
    case = {
        "name": args.name,
        "state": state,
        "command": args.command or "",
        "duration": float(args.duration or 0),
        "error": args.error or "",
        "last_run": now_iso() if state in ("executando", "aprovado", "reprovado", "ignorado") else None,
    }
    idx = _find(cases, "name", args.name)
    if idx is None:
        cases.append(case)
    else:
        cases[idx] = case

    # Recompute counters.
    executed = sum(1 for c in cases if c["state"] != "nao_executado")
    running = sum(1 for c in cases if c["state"] == "executando")
    passed = sum(1 for c in cases if c["state"] == "aprovado")
    failed = sum(1 for c in cases if c["state"] == "reprovado")
    skipped = sum(1 for c in cases if c["state"] == "ignorado")
    total = len(cases)
    duration = sum(float(c.get("duration") or 0) for c in cases)
    tests["executed"] = executed
    tests["running"] = running
    tests["passed"] = passed
    tests["failed"] = failed
    tests["skipped"] = skipped
    tests["total"] = total
    tests["duration_seconds"] = round(duration, 3)
    if args.command:
        tests["command"] = args.command
    if state in ("aprovado", "reprovado", "ignorado"):
        tests["last_result"] = state
        tests["last_run"] = now_iso()
    if state == "reprovado" and args.error:
        errors = tests.setdefault("errors", [])
        err_entry = {"test": args.name, "error": args.error, "at": now_iso()}
        if not any(e.get("test") == args.name for e in errors):
            errors.append(err_entry)
    st = data["state"]
    st["last_activity"] = f"Teste '{args.name}' -> {state}"
    save_state(data)
    print(f"Teste registrado: {args.name} ({state})")
    return 0


def cmd_problem(args: argparse.Namespace) -> int:
    data = load_state()
    problems = data.setdefault("problems", [])
    ptype = args.type
    if ptype not in PROBLEM_TYPES:
        print(f"Tipo inválido: {ptype}. Use: {', '.join(PROBLEM_TYPES)}", file=sys.stderr)
        return 2
    pstatus = args.status
    if pstatus not in PROBLEM_STATUSES:
        print(f"Status inválido: {pstatus}. Use: {', '.join(PROBLEM_STATUSES)}", file=sys.stderr)
        return 2
    entry = {
        "id": args.id,
        "type": ptype,
        "title": args.title,
        "description": args.description or "",
        "status": pstatus,
        "file": args.file or "",
        "region": args.region or "",
        "opened_at": now_iso(),
        "resolved_at": now_iso() if pstatus == "resolvido" else None,
        "history": [],
    }
    idx = _find(problems, "id", args.id)
    if idx is None:
        entry["history"].append(
            {"at": now_iso(), "action": "abertura", "by": AGENT, "detail": args.description or "Problema registrado."}
        )
        problems.append(entry)
    else:
        old = problems[idx]
        entry["opened_at"] = old.get("opened_at") or entry["opened_at"]
        entry["history"] = old.get("history", [])
        entry["history"].append(
            {"at": now_iso(), "action": "atualizacao", "by": AGENT, "detail": args.description or f"Status -> {pstatus}."}
        )
        if pstatus == "resolvido" and old.get("status") != "resolvido":
            entry["resolved_at"] = now_iso()
        problems[idx] = entry
    st = data["state"]
    st["last_activity"] = f"Problema '{args.id}' ({ptype}) -> {pstatus}"
    save_state(data)
    print(f"Problema registrado: {args.id} ({pstatus})")
    return 0


def cmd_history(args: argparse.Namespace) -> int:
    data = load_state()
    _append_history(data, args.action, args.detail)
    st = data["state"]
    st["last_activity"] = args.detail
    save_state(data)
    print("Histórico registrado.")
    return 0


def _append_history(data: dict, action: str, detail: str) -> None:
    history = data.setdefault("history", [])
    history.append(
        {"at": now_iso(), "session": data["meta"].get("current_session_id"), "action": action, "detail": detail}
    )


def cmd_heartbeat(args: argparse.Namespace) -> int:
    data = load_state()
    save_state(data)
    return 0


def cmd_show(args: argparse.Namespace) -> int:
    data = load_state()
    print(json.dumps(data, ensure_ascii=False, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Registra atividades no dashboard de acompanhamento.")
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init", help="Inicia uma nova sessão (preserva histórico).")
    p_init.add_argument("--task", default=None, help="Tarefa principal da sessão.")
    p_init.set_defaults(func=cmd_init)

    p_set = sub.add_parser("set", help="Atualiza campos do estado geral.")
    p_set.add_argument("--phase", choices=sorted(PHASES), default=None)
    p_set.add_argument("--status", default=None)
    p_set.add_argument("--progress", type=int, default=None)
    p_set.add_argument("--main-task", dest="main_task", default=None)
    p_set.add_argument("--last-activity", dest="last_activity", default=None)
    p_set.set_defaults(func=cmd_set)

    p_act = sub.add_parser("activity", help="Registra a atividade atual do agente.")
    p_act.add_argument("--what", default=None)
    p_act.add_argument("--file", default=None)
    p_act.add_argument("--region", default=None)
    p_act.add_argument("--function", default=None)
    p_act.add_argument("--objective", default=None)
    p_act.add_argument("--last-action", dest="last_action", default=None)
    p_act.add_argument("--next-action", dest="next_action", default=None)
    p_act.add_argument("--start", action="store_true", help="Marca início agora.")
    p_act.add_argument("--position-known", dest="position_known", action="store_true")
    p_act.add_argument("--position-unknown", dest="position_known", action="store_false")
    p_act.set_defaults(position_known=None, func=cmd_activity)

    p_step = sub.add_parser("step", help="Cadastra/atualiza uma etapa da linha do tempo.")
    p_step.add_argument("--id", required=True)
    p_step.add_argument("--name", required=True)
    p_step.add_argument("--state", required=True, choices=["concluida", "andamento", "pendente", "bloqueada"])
    p_step.add_argument("--started-at", dest="started_at", default=None)
    p_step.add_argument("--finished-at", dest="finished_at", default=None)
    p_step.add_argument("--description", default="")
    p_step.add_argument("--result", default="")
    p_step.set_defaults(func=cmd_step)

    p_file = sub.add_parser("file", help="Registra um arquivo em um bucket.")
    p_file.add_argument("--kind", required=True, choices=FILE_BUCKETS)
    p_file.add_argument("--path", required=True)
    p_file.add_argument("--note", default="")
    p_file.set_defaults(func=cmd_file)

    p_test = sub.add_parser("test", help="Cadastra/atualiza um caso de teste.")
    p_test.add_argument("--name", required=True)
    p_test.add_argument("--state", required=True, choices=TEST_STATES)
    p_test.add_argument("--command", default="")
    p_test.add_argument("--duration", type=float, default=0)
    p_test.add_argument("--error", default="")
    p_test.set_defaults(func=cmd_test)

    p_prob = sub.add_parser("problem", help="Cadastra/atualiza um problema.")
    p_prob.add_argument("--id", required=True)
    p_prob.add_argument("--type", required=True, choices=PROBLEM_TYPES)
    p_prob.add_argument("--title", required=True)
    p_prob.add_argument("--description", default="")
    p_prob.add_argument("--status", default="aberto", choices=PROBLEM_STATUSES)
    p_prob.add_argument("--file", default="")
    p_prob.add_argument("--region", default="")
    p_prob.set_defaults(func=cmd_problem)

    p_hist = sub.add_parser("history", help="Acrescenta uma entrada ao histórico.")
    p_hist.add_argument("--action", required=True)
    p_hist.add_argument("--detail", required=True)
    p_hist.set_defaults(func=cmd_history)

    p_hb = sub.add_parser("heartbeat", help="Apenas atualiza o carimbo de tempo (atividade contínua).")
    p_hb.set_defaults(func=cmd_heartbeat)

    p_show = sub.add_parser("show", help="Imprime o estado JSON atual.")
    p_show.set_defaults(func=cmd_show)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
