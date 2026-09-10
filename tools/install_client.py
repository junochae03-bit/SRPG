"""Install a verified portable client into a new/empty directory, without deletion.

Only the executable, PCK, three notices and explicitly named personal save files
are delivered. Receipts live outside the client. Save JSON checks here protect
the copy boundary; the Godot loader remains the authority on gameplay validity.
This tool neither launches the game nor migrates/rewrites personal data.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
DELIVERY = {
    "StelRPG.exe": "StelRPG.exe",
    "StelRPG.pck": "StelRPG.pck",
    "ASSET_SOURCES.md": "licenses/ASSET_SOURCES.md",
    "GODOT_LICENSE.txt": "licenses/GODOT_LICENSE.txt",
    "GODOT_COPYRIGHT.txt": "licenses/GODOT_COPYRIGHT.txt",
}
SETTINGS = ("sprite-names.json", "keybindings.json", "game-options.json")
SAVE_NAMES = tuple(f"slot-{i}.json{suffix}" for i in range(1, 4) for suffix in ("", ".bak"))
# Same envelope as LocalSession.parse_save: 120 bag cells plus seven equipped slots.
MAX_SAVED_EQUIPMENT = 120 + 7


class InstallError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InstallError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def regular_path(path):
    """Reject symlinks/junctions before following any input or output path."""
    path = Path(os.path.abspath(path))
    for part in (path, *path.parents):
        require(not part.is_symlink(), f"Symbolic link is not allowed: {part}")
        if part.exists():
            require(not (getattr(part.stat(), "st_file_attributes", 0) & 0x400),
                    f"Reparse point is not allowed: {part}")
    return path


def read_json(path, limit=8 * 1024 * 1024):
    path = regular_path(path)
    require(path.is_file() and path.stat().st_size <= limit, f"Missing/oversized JSON: {path}")
    try:
        value = json.loads(path.read_bytes().decode("utf-8-sig"),
                           parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
    except (UnicodeError, ValueError) as error:
        raise InstallError(f"Invalid JSON: {path}: {error}") from error
    require(isinstance(value, dict), f"Expected JSON object: {path}")
    return value


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def valid_slot(value):
    if not number(value.get("schema_version")) or value["schema_version"] not in range(1, 8):
        return False
    if not isinstance(value.get("name"), str) or not value["name"].strip():
        return False
    if any(not number(value.get(key)) or value[key] < 0 for key in
           ("level", "xp", "gold", "potions", "kills", "boss_kills", "world_seed")):
        return False
    if not 1 <= value["level"] <= 100 or value["potions"] > 20:
        return False
    if not isinstance(value.get("equipped"), str) or type(value.get("quest_done")) is not bool:
        return False
    items = value.get("inventory")
    if not isinstance(items, list) or len(items) > MAX_SAVED_EQUIPMENT:
        return False
    ids = []
    for item in items:
        if not isinstance(item, dict) or not isinstance(item.get("id"), str) or not isinstance(item.get("name"), str):
            return False
        if any(not number(item.get(key)) or item[key] < 0 for key in ("bonus", "rarity")):
            return False
        if item["id"] in ids:
            return False
        ids.append(item["id"])
    if value["equipped"] and value["equipped"] not in ids:
        return False
    for key in ("equipment", "materials", "stats", "skill_ranks", "skill_loadout", "constellation_allocations"):
        if key in value and not isinstance(value[key], dict):
            return False
    if "owned_appearances" in value:
        owned = value["owned_appearances"]
        if not isinstance(owned, list) or any(not isinstance(item, str) for item in owned) or len(set(owned)) != len(owned):
            return False
    return True


def valid_settings(name, value):
    if name == "game-options.json":
        options = value.get("values")
        expected = {"music", "effects", "window_mode", "resolution", "fps", "vsync", "damage_numbers", "enemy_names"}
        return (value.get("version") == 1 and isinstance(options, dict) and set(options) == expected and
                all(number(options[key]) and 0 <= options[key] <= 1 for key in ("music", "effects")) and
                options["window_mode"] in ("windowed", "fullscreen") and
                number(options["resolution"]) and options["resolution"] in (0, 1, 2) and
                number(options["fps"]) and options["fps"] in (0, 30, 60, 120, 144) and
                all(type(options[key]) is bool for key in ("vsync", "damage_numbers", "enemy_names")))
    if name == "sprite-names.json":
        return all(isinstance(key, str) and isinstance(alias, str) and
                   1 <= len(alias.strip()) <= 24 and not any(ord(c) < 32 or ord(c) == 127 for c in alias)
                   for key, alias in value.items())
    bindings = value.get("bindings")
    return (value.get("schema_version") == 1 and isinstance(bindings, dict) and bool(bindings) and
            all(isinstance(key, str) and number(code) and code > 0 and int(code) == code
                for key, code in bindings.items()) and len(set(bindings.values())) == len(bindings))


def source_record(path, relative):
    path = regular_path(path)
    require(path.is_file(), f"Missing source file: {path}")
    return {"path": relative, "source": str(path), "bytes": path.stat().st_size, "sha256": digest(path)}


def export_records(root, version):
    require(re.fullmatch(r"V\d+\.\d+(?:\.\d+)?", version), "Expected version such as V0.5.1")
    key = version.lower().replace(".", "")
    manifest_path = root / f"artifacts/export-{key}.json"
    checks_path = root / f"artifacts/export-check-{key}.json"
    manifest, checks = read_json(manifest_path), read_json(checks_path)
    for report in (manifest, checks):
        require(report.get("status") == "PASS" and report.get("version") == version,
                "Both export manifest and executable checks must pass for the requested version")
    require(bool(manifest.get("verified_runtime_sha256")), "Export has no verified runtime fingerprint")
    directory = regular_path(root / "releases" / version / f"StelRPG-{version}-Windows")
    files = manifest.get("files")
    require(isinstance(files, list), "Export manifest has no file list")
    indexed = {}
    for row in files:
        require(isinstance(row, dict) and isinstance(row.get("name"), str), "Invalid export entry")
        name = row["name"]
        require(name not in ("", ".", "..") and not any(c in name for c in "/\\:") and name not in indexed,
                f"Unsafe/duplicate export filename: {name}")
        record = source_record(directory / name, DELIVERY.get(name, name))
        require(record["sha256"] == row.get("sha256") and record["bytes"] == row.get("bytes"),
                f"Export changed after verification: {name}")
        indexed[name] = record
    require(DELIVERY.keys() <= indexed.keys(), "Export is missing a required executable or notice")
    for name, key in (("StelRPG.exe", "executable_sha256"), ("StelRPG.pck", "pck_sha256")):
        require(checks.get(key) == indexed[name]["sha256"], f"Executable test used a different {name}")
    evidence = [source_record(path, path.name) for path in (manifest_path, checks_path)]
    return [indexed[name] for name in DELIVERY], evidence


def save_records(directory):
    directory = regular_path(directory)
    require(directory.is_dir(), f"Save source must be the existing saves directory: {directory}")
    records, skipped, slots = [], [], set()
    for name in SAVE_NAMES:
        path = directory / name
        if not path.exists() and not path.is_symlink():
            continue
        regular_path(path)
        record = source_record(path, "saves/" + name)
        try:
            require(valid_slot(read_json(path)), f"Invalid slot structure: {path}")
        except InstallError as error:
            skipped.append({"name": name, "reason": str(error)})
            continue
        unchanged([record])
        records.append(record)
        slots.add(name[5])
    # Never silently discard an existing character whose primary and backup fail.
    for invalid in skipped:
        require(invalid["name"][5] in slots,
                f"No valid primary/backup for {invalid['name']}; source remains untouched")
    require(bool(slots), "No valid source slot JSON or backup found")
    for name in SETTINGS:
        path = directory / name
        if path.exists() or path.is_symlink():
            record = source_record(path, "saves/" + name)
            require(valid_settings(name, read_json(path)), f"Invalid personal settings: {path}")
            unchanged([record])
            records.append(record)
    return records, skipped


def unchanged(records):
    for row in records:
        source = regular_path(row["source"])
        require(source.is_file() and source.stat().st_size == row["bytes"] and digest(source) == row["sha256"],
                f"Source changed during delivery; retry after saving: {source}")


def exact_files(directory, records):
    directory = regular_path(directory)
    require(directory.is_dir(), f"Missing client directory: {directory}")
    expected = {row["path"]: row for row in records}
    require(len(expected) == len(records), "Duplicate receipt destination")
    expected_dirs = {str(Path(name).parent).replace("\\", "/") for name in expected if "/" in name}
    found, dirs = set(), set()
    for path in directory.rglob("*"):
        regular_path(path)
        relative = path.relative_to(directory).as_posix()
        if path.is_dir():
            dirs.add(relative)
        else:
            require(path.is_file() and relative in expected, f"Unexpected client file: {relative}")
            row = expected[relative]
            require(path.stat().st_size == row["bytes"] and digest(path) == row["sha256"],
                    f"Client checksum mismatch: {relative}")
            found.add(relative)
    require(found == expected.keys() and dirs == expected_dirs, "Client files/directories differ from receipt")


def empty_target(target):
    regular_path(target)
    require(not target.exists() or (target.is_dir() and not any(target.iterdir())),
            f"Target must be absent or completely empty; nothing will be overwritten: {target}")


def copy_new(source, destination):
    regular_path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with Path(source).open("rb") as incoming, destination.open("xb") as outgoing:
        shutil.copyfileobj(incoming, outgoing, 1024 * 1024)
        outgoing.flush()
        os.fsync(outgoing.fileno())


def install(version, target, save_source, root=ROOT):
    root, target, save_source = map(regular_path, (root, target, save_source))
    require(target != save_source and target not in save_source.parents and save_source not in target.parents,
            "Client target and source saves must not overlap")
    require(target != root and target not in root.parents and root not in target.parents,
            "Client target must be outside the source project")
    empty_target(target)
    records, evidence = export_records(root, version)
    personal, skipped = save_records(save_source)
    records += personal
    token = uuid.uuid4().hex
    stage = target.parent / f".{target.name}.install-{token}"
    receipt_path = root / "runtime/install-receipts" / f"{version}-{token}.json"
    regular_path(stage)
    target.parent.mkdir(parents=True, exist_ok=True)
    stage.mkdir()
    try:
        for row in records:
            copy_new(row["source"], stage / row["path"])
        exact_files(stage, records)
        unchanged(records + evidence)
        empty_target(target)
        if not target.exists():
            # Same-parent rename publishes a complete directory when possible.
            stage.rename(target)
        else:
            # Existing empty directory: exclusive creation, never replace/delete.
            for row in records:
                copy_new(stage / row["path"], target / row["path"])
        exact_files(target, records)
        unchanged(records + evidence)
        receipt = {"schema_version": 1, "status": "PASS", "version": version,
                   "target": str(target), "save_source": str(save_source), "files": records,
                   "verification": evidence, "skipped_invalid_saves": skipped,
                   "retained_stage": str(stage) if stage.exists() else None,
                   "save_validation": "JSON structural checks only; gameplay validity belongs to the Godot loader"}
        regular_path(receipt_path)
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        with receipt_path.open("x", encoding="utf8", newline="\n") as stream:
            json.dump(receipt, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        return receipt_path
    except Exception as error:
        raise InstallError(f"Delivery stopped; no files deleted or overwritten. Stage: {stage}. {error}") from error


def check_install(receipt_path, target=None):
    receipt = read_json(receipt_path)
    require(receipt.get("schema_version") == 1 and receipt.get("status") == "PASS", "No completed installation receipt")
    saved_target = regular_path(receipt["target"])
    if target is not None:
        require(regular_path(target) == saved_target, "Target differs from installation receipt")
    records = receipt.get("files", [])
    allowed = set(DELIVERY.values()) | {"saves/" + name for name in SAVE_NAMES + SETTINGS}
    require(isinstance(records, list) and bool(records) and
            all(isinstance(row, dict) and row.get("path") in allowed for row in records), "Unsafe receipt file list")
    require(set(DELIVERY.values()) <= {row["path"] for row in records}, "Receipt lacks required client files")
    exact_files(saved_target, records)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="V0.5.1")
    parser.add_argument("--target", type=Path)
    parser.add_argument("--save-source", type=Path, help="Existing saves directory, not the executable folder")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    try:
        if args.check:
            require(args.receipt is not None, "--check requires --receipt")
            receipt = check_install(args.receipt, args.target)
            print(json.dumps({"status": "PASS", "target": receipt["target"], "files": len(receipt["files"])}, ensure_ascii=False))
        else:
            require(args.target is not None and args.save_source is not None, "Installation requires --target and --save-source")
            require(args.receipt is None, "Receipts are generated automatically outside the client")
            receipt = install(args.version, args.target, args.save_source)
            print(json.dumps({"status": "PASS", "receipt": str(receipt)}, ensure_ascii=False))
    except (InstallError, OSError) as error:
        print(f"INSTALL_CLIENT_REFUSED {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
