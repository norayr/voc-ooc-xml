"""Check XML 1.0 well-formedness using the bundled James Clark fixtures."""

import argparse
from pathlib import Path
import subprocess
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--work", type=Path, default=Path("build/conformance"))
    args = parser.parse_args()
    executable = args.executable.resolve()
    args.work.mkdir(parents=True, exist_ok=True)
    archive = Path(__file__).resolve().parents[1] / "3rd-party-archives/xmltest.tar.gz"
    with tarfile.open(archive) as source:
        source.extractall(args.work, filter="data")
    root = args.work / "xmltest"
    failures = []
    skipped = []
    total = 0
    for category in ("valid", "not-wf"):
        for path in sorted((root / category).glob("*/*.xml")):
            if path.relative_to(root).as_posix() == "valid/sa/065.xml":
                # The upstream tests/xmltest/valid.sh excludes this fixture:
                # its entity replacement text does not match XML content.
                skipped.append("valid/sa/065.xml: malformed entity replacement (upstream exclusion)")
                continue
            total += 1
            try:
                result = subprocess.run(
                    [str(executable), "--external", str(path.resolve())],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5,
                )
                expected = 0 if category == "valid" else 1
                if result.returncode != expected:
                    failures.append(f"{path.relative_to(root)}: exit {result.returncode}\n"
                                    + result.stdout.decode("utf-8", errors="replace"))
            except subprocess.TimeoutExpired:
                failures.append(f"{path.relative_to(root)}: timeout")
    report = args.work / "xmltest-results.txt"
    if total != 360:
        failures.append(f"Incomplete corpus: expected 360 included fixtures, found {total}")
    report.write_text("\n".join(skipped + failures) + "\n", encoding="utf-8")
    print(f"xmltest well-formedness: {total - len(failures)}/{total} passed")
    print(f"Details: {report}")
    for reason in skipped:
        print(f"Skipped: {reason}")
    if failures:
        print("\n".join(failures))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
