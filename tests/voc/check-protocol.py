"""Compare the five original parser-callback protocol snapshots."""

import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--work", type=Path, default=Path("build/conformance"))
    args = parser.parse_args()
    executable = args.executable.resolve()
    root = Path(__file__).resolve().parents[1] / "protocol"
    args.work.mkdir(parents=True, exist_ok=True)
    paths = sorted((root / "valid").glob("???.xml"))
    if len(paths) != 5:
        raise SystemExit(f"Incomplete protocol corpus: expected 5 cases, found {len(paths)}")
    failures = []
    for path in paths:
        name = path.relative_to(root).as_posix()
        expected = (path.parent / "out" / path.name).read_bytes()
        try:
            result = subprocess.run([str(executable), "--external", "--protocol", name],
                                    cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5)
            if result.returncode:
                failures.append(f"{name}: exit {result.returncode}\n"
                                + result.stdout.decode("utf-8", errors="replace"))
            elif result.stdout != expected:
                offset = next((i for i, (a, b) in enumerate(zip(result.stdout, expected)) if a != b),
                              min(len(result.stdout), len(expected)))
                failures.append(f"{name}: byte mismatch at {offset}\n"
                                f"actual: {result.stdout[offset:offset+100]!r}\n"
                                f"expected: {expected[offset:offset+100]!r}")
        except subprocess.TimeoutExpired:
            failures.append(f"{name}: timeout")
    (args.work / "parser-protocol.txt").write_text("\n".join(failures) + "\n", encoding="utf-8")
    print(f"Parser protocol output: {len(paths) - len(failures)}/{len(paths)} passed")
    if failures:
        raise SystemExit("\n".join(failures))


if __name__ == "__main__":
    main()
