#!/usr/bin/env python3
"""Fail CI on Godot errors as well as exit codes; bound hung test scenes."""
import os
import re
import subprocess
import sys


def main():
    try:
        result = subprocess.run(
            [os.environ.get("GODOT_BIN", "godot"), *sys.argv[1:]],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=int(os.environ.get("GODOT_TIMEOUT", "180")),
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        print(output.decode(errors="replace") if isinstance(output, bytes) else output)
        print("Godot validation timed out", file=sys.stderr)
        return 1
    print(result.stdout, end="")
    return 1 if result.returncode or re.search(
        r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:)", result.stdout
    ) else 0


if __name__ == "__main__":
    sys.exit(main())
