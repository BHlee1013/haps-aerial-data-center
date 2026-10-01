#!/usr/bin/env python3
"""Dependency-free package/frozen-computation integrity check; no analysis runs.

Usage: python tools/verify_release_candidate.py [--root REPOSITORY] [--report JSON]
The report, when requested, must be outside the packaged immutable inputs/docs.
This is a checksum verifier, not a signature or a license/model-validity check.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read_list(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != ["file", "bytes", "sha256"]:
            raise ValueError(f"Unexpected checksum header: {path.name}")
        rows = list(reader)
    if not rows or len({row["file"] for row in rows}) != len(rows):
        raise ValueError("The checksum list is empty or contains duplicate paths.")
    for row in rows:
        rel = row["file"]
        if (PurePosixPath(rel).is_absolute() or ".." in PurePosixPath(rel).parts
                or ":" in rel or "\\" in rel):
            raise ValueError(f"Unsafe relative path: {rel!r}")
        if not row["bytes"].isdigit() or not re.fullmatch(r"[0-9a-fA-F]{64}", row["sha256"]):
            raise ValueError(f"Invalid size/hash for {rel!r}")
    return rows


def verify_list(root: Path, rows: list[dict[str, str]]) -> list[dict[str, object]]:
    result = []
    for row in rows:
        path = root.joinpath(*PurePosixPath(row["file"]).parts)
        exists = path.is_file()
        size_ok = exists and path.stat().st_size == int(row["bytes"])
        hash_ok = exists and digest(path) == row["sha256"].lower()
        result.append({"file": row["file"], "exists": exists, "size_ok": size_ok,
                       "hash_ok": hash_ok, "passed": exists and size_ok and hash_ok})
    return result


def unlisted_code(root: Path, known: set[str]) -> list[str]:
    paths = set(root.glob("*.m"))
    for subdir, pattern in [("code", "*.m"), ("code", "*.py"),
                            ("models", "*.slx"), ("data/processed", "*.csv")]:
        paths.update((root / subdir).rglob(pattern))
    return sorted(path.relative_to(root).as_posix() for path in paths
                  if path.is_file() and path.relative_to(root).as_posix() not in known)


def verify(root: Path) -> dict[str, object]:
    manifest = root / "docs/release_file_checksums.csv"
    anchor = (root / "SHA256SUMS").read_text(encoding="utf-8").strip()
    match = re.fullmatch(r"([0-9a-fA-F]{64})  docs/release_file_checksums\.csv", anchor)
    if not match or digest(manifest) != match[1].lower():
        raise ValueError("The checksum manifest or its SHA256SUMS anchor was changed.")
    rows = read_list(manifest)
    package = verify_list(root, rows)
    frozen = verify_list(root, read_list(root / "docs/frozen_computational_files.csv"))
    extra = unlisted_code(root, {row["file"] for row in rows})
    meta = json.loads((root / "docs/release_status.json").read_text(encoding="utf-8"))
    package_ok = all(row["passed"] for row in package)
    frozen_ok = all(row["passed"] for row in frozen)
    return {"version": meta["version"], "passed": package_ok and frozen_ok and not extra,
            "package_files_checked": len(package), "frozen_files_checked": len(frozen),
            "package_integrity_passed": package_ok, "computational_freeze_passed": frozen_ok,
            "no_unlisted_code": not extra, "unlisted_computational_files": extra,
            "publication_ready": meta["publication_ready"],
            "publication_gates": meta["publication_gates"],
            "failed_package_files": [row for row in package if not row["passed"]],
            "failed_frozen_files": [row for row in frozen if not row["passed"]],
            "scope": "File integrity only. No MATLAB/Simscape/scientific analysis executed."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        result = verify(root)
    except (OSError, ValueError, KeyError, csv.Error) as exc:
        result = {"passed": False, "error": str(exc), "scope": "File integrity only."}
    if args.report is not None:
        target = args.report.resolve()
        generated = root / "data/results/generated"
        if target.is_relative_to(root) and not target.is_relative_to(generated):
            print("Report must be outside the repository or inside data/results/generated/.", file=sys.stderr)
            return 2
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
