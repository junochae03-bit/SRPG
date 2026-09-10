"""Isolated stdlib tests; never accesses a real client or user save folder."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import install_client as installer


class ClientInstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="stel-install-test-")
        self.addCleanup(self.temporary.cleanup)
        self.workspace = Path(self.temporary.name).resolve()
        self.root = self.workspace / "project"
        self.root.mkdir()
        self.target = self.workspace / "client"
        self.source = self.workspace / "previous client/saves"
        self.source.mkdir(parents=True)
        self.version = "V0.5.1"
        self.out = self.root / "releases/V0.5.1/StelRPG-V0.5.1-Windows"
        self.out.mkdir(parents=True)
        (self.root / "artifacts").mkdir()
        for name in installer.DELIVERY:
            (self.out / name).write_bytes((name + "\r\n검증된 파일\r\n").encode("utf8"))
        # A package can contain documentation; this delivery must remain minimal.
        (self.out / "시작 안내.txt").write_text("not part of minimal client", "utf8")
        (self.out / "debug.log").write_text("private debug output", "utf8")
        (self.out / "scripts").mkdir()
        (self.out / "scripts/main.gd").write_text("unused source", "utf8")
        (self.out / "saves").mkdir()
        (self.out / "saves/slot-1.json").write_text("stale export fixture", "utf8")
        self.manifest_path = self.root / "artifacts/export-v051.json"
        self.checks_path = self.root / "artifacts/export-check-v051.json"
        self.write(self.manifest_path, {
            "version": self.version, "status": "PASS", "verified_runtime_sha256": {"game/main.gd": "a" * 64},
            "files": [{"name": name, "bytes": (self.out / name).stat().st_size,
                       "sha256": installer.digest(self.out / name)} for name in (*installer.DELIVERY, "시작 안내.txt")]})
        self.write(self.checks_path, {"version": self.version, "status": "PASS",
                                    "executable_sha256": installer.digest(self.out / "StelRPG.exe"),
                                    "pck_sha256": installer.digest(self.out / "StelRPG.pck")})
        self.save = {"schema_version": 7, "name": "별빛 기록", "level": 5, "xp": 73,
                     "gold": 923, "potions": 5, "kills": 12, "boss_kills": 0, "world_seed": 542,
                     "equipped": "", "quest_done": False, "inventory": [], "stats": {"strength": 6},
                     "owned_appearances": ["costume:example"], "future_preserved": {"arbitrary": [1, 2]}}
        self.write(self.source / "slot-1.json", self.save)

    @staticmethod
    def write(path, value):
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", "utf8")

    def read(self, path):
        return json.loads(path.read_text("utf8"))

    @staticmethod
    def fingerprints(directory):
        return {p.relative_to(directory).as_posix(): installer.digest(p) for p in directory.rglob("*") if p.is_file()}

    def install(self):
        return installer.install(self.version, self.target, self.source, self.root)

    def test_minimal_delivery_and_exact_personal_bytes(self):
        self.target.mkdir()  # Matches the intended already-empty destination.
        self.write(self.source / "slot-2.json", {**self.save, "name": "둘째", "gold": 17})
        self.write(self.source / "slot-2.json.bak", {**self.save, "name": "둘째", "gold": 16})
        self.write(self.source / "slot-3.json", {**self.save, "name": "셋째"})
        self.write(self.source / "sprite-names.json", {"costume:example": "나의 별빛 의상"})
        self.write(self.source / "keybindings.json", {"schema_version": 1, "bindings": {"move_up": 87, "bag": 73}})
        self.write(self.source / "game-options.json", {"version": 1, "values": {"music": 0.2, "effects": 0.8,
                   "window_mode": "windowed", "resolution": 0, "fps": 60, "vsync": True,
                   "damage_numbers": True, "enemy_names": False}})
        (self.source / "audio-settings.json").write_text("not requested", "utf8")
        (self.source / "slot-2.json.corrupt-old").write_text("for recovery only", "utf8")
        before = self.fingerprints(self.workspace)
        receipt_path = self.install()
        receipt = installer.check_install(receipt_path, self.target)
        expected = set(installer.DELIVERY.values()) | {"saves/" + name for name in
                    ("slot-1.json", "slot-2.json", "slot-2.json.bak", "slot-3.json", *installer.SETTINGS)}
        self.assertEqual(set(self.fingerprints(self.target)), expected)
        self.assertFalse(receipt_path.is_relative_to(self.target))
        self.assertEqual(receipt["status"], "PASS")
        for row in receipt["files"]:
            self.assertEqual((self.target / row["path"]).read_bytes(), Path(row["source"]).read_bytes())
        after = self.fingerprints(self.workspace)
        for name, digest in before.items():
            self.assertEqual(after[name], digest, "Original file changed: " + name)

    def test_absent_target_publishes_complete_stage(self):
        receipt = installer.check_install(self.install())
        self.assertIsNone(receipt["retained_stage"])
        self.assertEqual(len(receipt["files"]), 6)

    def test_expanded_inventory_is_copied_without_truncation(self):
        self.save["inventory"] = [{"id": str(i), "name": "보관 장비", "bonus": 1, "rarity": 0}
                                  for i in range(127)]
        self.write(self.source / "slot-1.json", self.save)
        before = (self.source / "slot-1.json").read_bytes()
        installer.check_install(self.install())
        self.assertEqual((self.target / "saves/slot-1.json").read_bytes(), before)
        self.assertEqual((self.source / "slot-1.json").read_bytes(), before)
        self.assertTrue(installer.valid_slot(self.save))
        self.save["inventory"].append({"id": "128", "name": "초과", "bonus": 1, "rarity": 0})
        self.assertFalse(installer.valid_slot(self.save))

    def test_existing_save_refused_without_changes(self):
        (self.target / "saves").mkdir(parents=True)
        existing = self.target / "saves/slot-1.json"
        existing.write_bytes(b"unique player progress")
        before = self.fingerprints(self.workspace)
        with self.assertRaisesRegex(installer.InstallError, "empty"):
            self.install()
        self.assertEqual(self.fingerprints(self.workspace), before)

    def test_unknown_target_file_or_directory_refused(self):
        self.target.mkdir()
        (self.target / "notes").mkdir()
        with self.assertRaisesRegex(installer.InstallError, "empty"):
            self.install()
        self.assertEqual(list(self.target.iterdir()), [self.target / "notes"])

    def test_second_install_never_overwrites_even_identical_files(self):
        self.install()
        before = self.fingerprints(self.target)
        with self.assertRaisesRegex(installer.InstallError, "empty"):
            self.install()
        self.assertEqual(self.fingerprints(self.target), before)

    def test_unverified_or_wrong_version_export_refused(self):
        for field, value in (("status", "FAIL"), ("version", "V0.5")):
            with self.subTest(field=field):
                checks = self.read(self.checks_path)
                original = checks[field]
                checks[field] = value
                self.write(self.checks_path, checks)
                with self.assertRaisesRegex(installer.InstallError, "must pass"):
                    self.install()
                self.assertFalse(self.target.exists())
                checks[field] = original
                self.write(self.checks_path, checks)

    def test_export_or_executable_proof_hash_mismatch_refused(self):
        checks = self.read(self.checks_path)
        checks["pck_sha256"] = "b" * 64
        self.write(self.checks_path, checks)
        with self.assertRaisesRegex(installer.InstallError, "different StelRPG.pck"):
            self.install()
        checks["pck_sha256"] = installer.digest(self.out / "StelRPG.pck")
        self.write(self.checks_path, checks)
        (self.out / "StelRPG.exe").write_bytes(b"changed after checks")
        with self.assertRaisesRegex(installer.InstallError, "changed after verification"):
            self.install()
        self.assertFalse(self.target.exists())

    def test_missing_notice_and_unsafe_manifest_refused(self):
        manifest = self.read(self.manifest_path)
        removed = manifest["files"].pop(2)
        self.write(self.manifest_path, manifest)
        with self.assertRaisesRegex(installer.InstallError, "missing a required"):
            self.install()
        manifest["files"].append({**removed, "name": "../outside.txt"})
        self.write(self.manifest_path, manifest)
        with self.assertRaisesRegex(installer.InstallError, "Unsafe"):
            self.install()

    def test_invalid_primary_preserves_valid_backup_only(self):
        (self.source / "slot-1.json").write_bytes(b"interrupted JSON {")
        self.write(self.source / "slot-1.json.bak", self.save)
        receipt = installer.check_install(self.install())
        self.assertFalse((self.target / "saves/slot-1.json").exists())
        self.assertEqual((self.target / "saves/slot-1.json.bak").read_bytes(), (self.source / "slot-1.json.bak").read_bytes())
        self.assertEqual(receipt["skipped_invalid_saves"][0]["name"], "slot-1.json")
        self.assertEqual((self.source / "slot-1.json").read_bytes(), b"interrupted JSON {")

    def test_unrecoverable_slot_refused_even_if_another_slot_is_valid(self):
        (self.source / "slot-2.json").write_bytes(b"{}")
        with self.assertRaisesRegex(installer.InstallError, "No valid primary/backup"):
            self.install()
        self.assertFalse(self.target.exists())

    def test_invalid_settings_and_nonfinite_save_refused(self):
        self.write(self.source / "sprite-names.json", {"costume:example": ""})
        with self.assertRaisesRegex(installer.InstallError, "Invalid personal settings"):
            self.install()
        self.write(self.source / "sprite-names.json", {})
        (self.source / "slot-1.json").write_text(json.dumps({**self.save, "gold": float("nan")}), "utf8")
        with self.assertRaisesRegex(installer.InstallError, "No valid"):
            self.install()

    def test_changed_live_source_aborts_before_publication(self):
        original = installer.copy_new
        changed = False

        def copy_and_change(source, destination):
            nonlocal changed
            original(source, destination)
            if Path(source) == self.source / "slot-1.json" and not changed:
                changed = True
                self.write(Path(source), {**self.save, "gold": 777})

        with patch.object(installer, "copy_new", side_effect=copy_and_change):
            with self.assertRaisesRegex(installer.InstallError, "Source changed during delivery"):
                self.install()
        self.assertFalse(self.target.exists())
        self.assertEqual(self.read(self.source / "slot-1.json")["gold"], 777)

    def test_receipt_detects_extra_files_modified_saves_and_wrong_target(self):
        receipt = self.install()
        with self.assertRaisesRegex(installer.InstallError, "Target differs"):
            installer.check_install(receipt, self.workspace / "wrong-client")
        personal = self.target / "saves/slot-1.json"
        original = personal.read_bytes()
        personal.write_bytes(b"different progress")
        with self.assertRaisesRegex(installer.InstallError, "checksum mismatch"):
            installer.check_install(receipt)
        personal.write_bytes(original)
        (self.target / "debug.log").write_text("extra", "utf8")
        with self.assertRaisesRegex(installer.InstallError, "Unexpected client file"):
            installer.check_install(receipt)

    def test_source_target_overlap_and_symlinks_refused(self):
        with self.assertRaisesRegex(installer.InstallError, "overlap"):
            installer.install(self.version, self.source, self.source, self.root)
        with self.assertRaisesRegex(installer.InstallError, "outside the source project"):
            installer.install(self.version, self.root / "client", self.source, self.root)
        link = self.workspace / "linked-saves"
        try:
            link.symlink_to(self.source, target_is_directory=True)
        except OSError:
            return  # Windows without symbolic-link privilege still runs overlap checks.
        with self.assertRaisesRegex(installer.InstallError, "Symbolic link"):
            installer.install(self.version, self.target, link, self.root)


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=2).result
    print(f"INSTALL_CLIENT_TESTS tests={result.testsRun} failures={len(result.failures)} errors={len(result.errors)}")
    raise SystemExit(0 if result.wasSuccessful() else 1)
