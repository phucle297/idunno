#!/usr/bin/env python3
"""Verify an exported playtest bundle: flat manifest, hashes and PCK contents.

Usage: verify_exported_artifacts.py SHA256SUMS.txt

Standard library only; runs identically on Windows and Linux. Exits non-zero on
any mismatch. Used by tests/run_windows_package_checks.ps1 and by the export
verification recorded in docs/checklists/phase-3-player-caused-chaos.md.
"""
import hashlib
import struct
import sys
from pathlib import Path


REQUIRED_FILES = {"DisasterParty.pck", "BUILD.txt"}
BINARY_FILES = {"DisasterParty.exe", "DisasterParty.x86_64"}
OPTIONAL_FILES = {"room_service.py"}
FORBIDDEN_PREFIXES = (
    "res://tests/", "res://tools/", "res://docs/", "res://.agents/",
    "res://.scratch/", "res://.github/", "res://assets/source/",
    "res://assets/references/",
)
REQUIRED_PCK_ENTRIES = ("res://project.binary", "res://scenes/main.tscn")


def pck_entries(path):
    """Return the entry names of a Godot 4 PCK, validating the structure."""
    data = path.read_bytes()
    assert data[:4] == b"GDPC", "Not a Godot PCK"
    version = struct.unpack_from("<I", data, 4)[0]
    assert version == 4, f"Unsupported PCK format version: {version}"
    # Format v4: header (magic, format, engine version, flags, file_base,
    # directory offset, reserved), file data, then at the directory offset a
    # u32 count followed by records of
    # name_len, name (padded to 4), offset u64, size u64, md5[16], flags u32.
    file_base, directory = struct.unpack_from("<QQ", data, 24)
    assert file_base < directory < len(data), "Invalid PCK offsets"
    count = struct.unpack_from("<I", data, directory)[0]
    assert 1 <= count <= 100000, f"Implausible PCK entry count: {count}"
    offset = directory + 4
    names = []
    for _ in range(count):
        name_len = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        assert 1 <= name_len <= 4096
        raw = data[offset:offset + name_len]
        offset += name_len + (-name_len % 4)
        offset += 8 + 8 + 16  # offset, size, md5
        assert struct.unpack_from("<I", data, offset)[0] == 0, "Unexpected per-file flags"
        offset += 4
        name = raw.rstrip(b"\x00").decode("utf-8")
        assert name and not name.startswith("res://"), name
        names.append("res://" + name)
    assert offset == len(data), "Trailing bytes after PCK directory"
    return version, names


def main():
    manifest = Path(sys.argv[1])
    folder = manifest.parent
    files = {}
    for line in manifest.read_text().splitlines():
        digest, name = line.split(None, 1)
        assert Path(name).name == name, f"Non-flat manifest entry: {name}"
        files[name] = digest
    names = set(files)
    assert names & BINARY_FILES, "Missing platform binary"
    assert names <= (REQUIRED_FILES | BINARY_FILES | OPTIONAL_FILES), f"Unexpected files: {sorted(names)}"
    assert REQUIRED_FILES <= names, f"Missing files: {sorted(REQUIRED_FILES - names)}"
    for name, digest in files.items():
        actual = hashlib.sha256((folder / name).read_bytes()).hexdigest()
        assert actual == digest, f"Hash mismatch: {name}"

    version, entries = pck_entries(folder / "DisasterParty.pck")
    seen = set(entries)
    for required in REQUIRED_PCK_ENTRIES:
        assert required in seen, f"Missing PCK entry: {required}"
    leaked = [e for e in entries if e.startswith(FORBIDDEN_PREFIXES)]
    assert not leaked, f"Development paths leaked into PCK: {leaked[:5]}"
    assert any(e.startswith("res://game/") for e in entries), "No game scripts in PCK"
    print(f"PLAYTEST_ARTIFACTS_OK files={len(files)} pck_format={version} pck_entries={len(entries)}")


if __name__ == "__main__":
    main()
