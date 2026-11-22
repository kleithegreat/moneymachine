"""The one command-line entry point: `python -m cli <command> [args]`; `python -m cli -h` lists the commands.

Each command calls one function of a concept module. A returned value prints as JSON; files named
in the arguments are written by the function.
"""

import argparse
import importlib
import json
import sys
from collections.abc import Sequence

# name: (module, function, arguments, help). An argument is "name" or "name:int"; a trailing "?" makes it
# optional.
COMMANDS = {
    "archive-fetch": (
        "ingest.archive",
        "main",
        ["start", "end", "coins:str+", "--hours:int+", "--max-dollars:float"],
        "fetch Hyperliquid book archive days [start, end) for the coins and parse them (requester pays; max dollars default 1)",
    ),
    "sources-record": (
        "ingest.sources_record",
        "main",
        ["out_dir"],
        "the live forum and Snapshot recorder (until SIGTERM)",
    ),
    "datalayer-record": ("ingest.datalayer", "main", ["out_dir"], "the keyless data layer recorder (until SIGTERM)"),
}

TYPES = {"int": int, "float": float, "str": str}


def main(argv: Sequence[str]) -> None:
    parser = argparse.ArgumentParser(prog="python -m cli")
    sub = parser.add_subparsers(dest="command", required=True)
    for name, (_, _, args, help_) in COMMANDS.items():
        p = sub.add_parser(name, help=help_)
        for a in args:
            arg, _, kind = a.rstrip("?").partition(":")
            many = kind.endswith("+")
            nargs = "+" if many else ("?" if a.endswith("?") else None)
            p.add_argument(arg, nargs=nargs, type=TYPES[kind.rstrip("+")] if kind else str)
    ns = vars(parser.parse_args(argv))
    module, function, args, _ = COMMANDS[ns.pop("command")]
    out = getattr(importlib.import_module(module), function)(**{k: v for k, v in ns.items() if v is not None})
    if out is not None:
        print(json.dumps(out, indent=1) if not isinstance(out, str) else out)


if __name__ == "__main__":
    main(sys.argv[1:])
