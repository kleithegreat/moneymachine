"""The one command-line entry point: `python -m cli <command> [args]`; `python -m cli -h` lists the commands.

Each command calls one function of a concept module. A returned value prints as JSON; files named
in the arguments are written by the function.
"""

import argparse
import importlib
import importlib.util
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent


def check():
    """The whole suite at once: pytest over 6 workers, the kernel's cargo tests and the mutants. Each writes its
    log to data/check/; returns each part's last line and the lines naming each failed test or mutant, and exits
    nonzero if any part fails."""
    import re
    import subprocess

    logs = REPO / "data" / "check"
    logs.mkdir(parents=True, exist_ok=True)
    parts = {"pytest": (["pytest", "-q", "-n", "6", "--dist", "loadfile"], REPO),
             "cargo": (["cargo", "test", "-q", "--release"], REPO / "kernel"),
             "mutants": ([sys.executable, "-m", "cli", "mutants"], REPO)}
    procs = {k: subprocess.Popen(cmd, cwd=cwd, stdout=open(logs / f"{k}.log", "w"), stderr=subprocess.STDOUT)
             for k, (cmd, cwd) in parts.items()}
    codes = {k: p.wait() for k, p in procs.items()}
    failure = re.compile(r"^(FAILED|ERROR|MISSED|BROKEN) |^test .* FAILED$")
    lines = {k: (logs / f"{k}.log").read_text().strip().splitlines() for k in parts}
    out = {k: {"exit": c, "last": lines[k][-1:], "failed": [l for l in lines[k] if failure.match(l)]}
           for k, c in codes.items()}
    if any(codes.values()):
        print(json.dumps(out, indent=1))
        sys.exit(1)
    return out


def mutants():
    spec = importlib.util.spec_from_file_location("mutants", REPO / "kernel/mutants/mutants.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.main()


# name: (module, function, arguments, help). An argument is "name" or "name:int"; a trailing "?" makes it
# optional.
COMMANDS = {
    "universe": ("ingest.universe", "write", ["out"], "rank the stage 0 universe U into OUT"),
    "rules": ("ingest.rules", "write", ["data_root", "out"], "write the venue rules for U to OUT"),
    "backfill": ("ingest.backfill", "main", ["data_root", "budget:int"],
                 "fetch W for U into the store as one dataset version; the ingestion report goes to audit/stage0/"),
    "record": ("ingest.record", "main", ["universe_path", "rules_path", "out_dir", "budget:int?"], "the live Hyperliquid recorder (until SIGTERM; see recorder-restart)"),
    "availability": ("ingest.availability", "report", ["live_dir", "sources_dir", "out", "oci_dir?"],
                     "first observations of settled funding and closed bars in the judged window, and the NTP clock record over it"),
    "execution": ("ingest.execution", "calibrate", ["live_dir", "sources_dir", "model_out", "report_out", "oci_dir?"],
                  "the taker cost model from the judged L2 snapshots, and its held-out validation"),
    "witness": ("ingest.witness", "replay", ["data_root", "version:int", "out"], "W0's independent replay"),
    "holdout-hashes": ("ingest.holdout", "main", ["data_root", "audit_path"], "record the sha256 of new holdout files"),
    "sources-record": ("ingest.sources_record", "main", ["out_dir"], "the live forum and Snapshot recorder (until SIGTERM; see recorder-restart)"),
    "sources-backfill": ("ingest.sources_backfill", "main", ["data_root", "source?"], "backfill a source's item metadata as revisions"),
    "recorder-restart": ("ingest.live", "restart", ["out_dir", "budget:int?"],
                         "stop a recorder between polls (its pidfile) and start it again, optionally at a new budget"),
    "datalayer-record": ("ingest.datalayer", "main", ["out_dir"], "the keyless data layer recorder (until SIGTERM; see recorder-restart)"),
    "sources-availability": ("ingest.sources_avail", "analyze", ["live_dir", "source?"], "C5.3's reported availability figures for one source"),
    "sources-reconcile": ("ingest.sources_avail", "reconcile", ["data_root", "live_dir", "version:int", "source?"],
                          "a re-backfill against what was recorded live"),
    "events": ("ingest.events", "main", ["data_root", "version:int", "live_dir", "source?"],
               "derive hourly event counts per coin into the store"),
    "events-verify": ("ingest.events", "verify", ["lineage", "data_root", "live_dir"],
                      "recompute a derived version from its lineage manifest and compare"),
    "sources-coverage": ("ingest.sources_coverage", "report", ["data_root", "version:int", "live_dir"],
                         "per-coin event counts, coverage, gaps and classification"),
    "labels-sample": ("ingest.labels", "sample", ["source", "data_root", "out"], "draw items for blind labeling"),
    "labels-evaluate": ("ingest.labels", "evaluate", ["source", "sample_path", "labels_path"], "precision and recall of a mapping"),
    "fit-nulls": ("gate.fit", "write", ["data_root", "version:int", "out"], "fit N2/N3 to the search part; prints the hash"),
    "probes": ("gate.probes", "run", ["out", "data_root?", "version:int?"],
               "null-market regression and probes; with a dataset, real event counts replayed"),
    "probes-top5": ("gate.probes", "top5", ["out"], "the probes plus the complete-null sweep's first in-sample top-5 strategies"),
    "null-agreement": ("gate.tests.null_agreement", "run", ["out"], "our N2/N3 generators against GPT's"),
    "freeze-searcher": ("gate.sweep", "freeze_searcher", [], "record the stage 2 searchers' pin, once, before any sweep"),
    "betas": ("gate.sweep", "betas", [], "calibrate the planted signal's beta to the target Sharpes"),
    "sweep": ("gate.sweep", "sweep", ["name", "data_root?", "version:int?"], "run the null, mixed or events sweep (resumable)"),
    "truth": ("gate.sweep", "truth", [], "judge each mixed-sweep promotion on fresh years"),
    "sweep-summary": ("gate.sweep", "summary", ["out"], "sweep counts and bounds"),
    "holdout-size": ("gate.size", "main", ["work", "audit"], "the holdout test's locked calibration (gate/null_suite.py)"),
    "freeze-harness": ("gate.agent.campaigns", "freeze_harness", [], "record the agent harness hash, once"),
    "agent-null": ("gate.agent.campaigns", "run_series", ["name", "n:int"], "agent or swarm null campaigns (paced, resumable)"),
    "agent-real": ("gate.agent.campaigns", "real", ["data_root", "version:int"], "the one real campaign, both arms"),
    "agent-summary": ("gate.agent.campaigns", "summary", ["name", "out"], "an agent or swarm null series beside its baseline"),
    "differential-run": ("reference.differential", "run", ["out", "workers?"], "C6.4's judged run of mm against refmm on the frozen corpus"),
    "mutants": ("cli", "mutants", [], "apply each mutant to a copy of the tree; its named test must fail"),
    "check": ("cli", "check", [], "pytest, cargo tests and mutants concurrently (run it in a capped scope)"),
    "thesis-freeze": ("thesis.runner", "freeze", [], "freeze the thesis track manifest (starts a track version)"),
    "thesis-run": ("thesis.runner", "run", [], "the thesis track's schedule (runs until killed)"),
    "thesis-report": ("thesis.runner", "report", ["out"], "the thesis track's report"),
}

TYPES = {"int": int}


def main(argv):
    parser = argparse.ArgumentParser(prog="python -m cli")
    sub = parser.add_subparsers(dest="command", required=True)
    for name, (_, _, args, help_) in COMMANDS.items():
        p = sub.add_parser(name, help=help_)
        for a in args:
            arg, _, kind = a.rstrip("?").partition(":")
            p.add_argument(arg, nargs="?" if a.endswith("?") else None, type=TYPES.get(kind, str))
    ns = vars(parser.parse_args(argv))
    module, function, args, _ = COMMANDS[ns.pop("command")]
    out = getattr(importlib.import_module(module), function)(**{k: v for k, v in ns.items() if v is not None})
    if out is not None:
        print(json.dumps(out, indent=1) if not isinstance(out, str) else out)


if __name__ == "__main__":
    main(sys.argv[1:])
