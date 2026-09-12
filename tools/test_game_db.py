"""Engine-free DB contract/SQLite tests. No canonical files are written."""
import copy
import sqlite3
import struct
import unittest

import game_db_rules as db


def fixture():
    data = {table: [] for table in db.TABLES}
    data.update({"metadata": {}, "facilities": [{"id": key, "name": key} for key in
                 ("smith", "shop", "alchemy", "guild", "inn", "costume", "training")],
                 "item_definitions": [{"id": "seed", "name": "seed"}, {"id": "potion", "name": "potion"}],
                 "service_operations": [{"id": "alchemy:potion", "facility_id": "alchemy", "operation": "potion", "route": "town_operations"}],
                 "service_samples": [{"id": "sample", "operation_id": "alchemy:potion", "quantity": 1, "gold_cost": 10, "gold_reward": 0, "storage_checked": False}],
                 "service_inputs": [{"id": "input", "operation_id": "alchemy:potion", "sample_id": "sample", "item_id": "seed", "amount": 3}],
                 "service_outputs": [{"id": "output", "operation_id": "alchemy:potion", "sample_id": "sample", "item_id": "potion", "amount": 3}],
                 "dungeon_layouts": [{"id": "test", "selection_order": 0, "points": [[0, 0], [1, 1], [2, 2]], "links": [[0, 1], [1, 2]]}],
                 "inventory_rules": [{"id": "inventory", "width": 10, "height": 12, "capacity": 120, "max_potions": 20, "max_materials": 999999}],
                 "training_rules": [{"id": "training", "facility_id": "training", "health": 1000, "area": [0, 0, 10, 10], "position": [5, 5], "empty_summary": {"dps": 0}}]})
    return db.enrich(data, db.ROOT)


class ContractTests(unittest.TestCase):
    def setUp(self): self.data = fixture()

    def test_source_symbols_and_routes(self):
        db.validate(self.data)
        ids = [r["id"] for r in self.data["service_operations"]]
        self.assertEqual(ids.count("alchemy:potion"), 1)
        self.assertIn("smith:upgrade", ids)
        self.assertEqual(self.data["metadata"]["schema_version"], 5)
        self.assertIn("return", self.data["training_rules"][0]["reward_rule"]["source_code"])

    def test_reject_invalid_contracts(self):
        mutations = [lambda d: d["service_inputs"][0].update(item_id="missing"),
                     lambda d: d["service_inputs"][0].update(operation_id="shop:buy"),
                     lambda d: d["service_outputs"][0].update(amount=0),
                     lambda d: d["service_samples"][0].update(gold_reward=1),
                     lambda d: d["inventory_rules"][0].update(capacity=60),
                     lambda d: d["inventory_rules"][0].update(max_materials=0),
                     lambda d: d["inventory_rules"][0].update(max_materials=1.5),
                     lambda d: d["dungeon_layouts"][0].update(links=[[0, 1]]),
                     lambda d: d["training_rules"][0].update(position=[10, 5])]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                bad = copy.deepcopy(self.data); mutation(bad)
                with self.assertRaises(AssertionError): db.validate(bad)

    def test_sqlite_fk_and_round_trip(self):
        with sqlite3.connect(":memory:") as con:
            con.execute("PRAGMA foreign_keys=ON")
            con.executescript(db.SCHEMA)
            db.insert(con, self.data)
            self.assertFalse(con.execute("PRAGMA foreign_key_check").fetchall())
            self.assertEqual(con.execute("PRAGMA user_version").fetchone()[0], 5)
            self.assertEqual(con.execute("SELECT amount FROM service_outputs").fetchone()[0], 3)
            self.assertEqual(con.execute("SELECT max_materials FROM inventory_rules").fetchone()[0], 999999)
            for invalid in (0, -1, 1.5):
                with self.assertRaises(sqlite3.IntegrityError):
                    con.execute("UPDATE inventory_rules SET max_materials=?", (invalid,))
            with self.assertRaises(sqlite3.IntegrityError):
                con.execute("UPDATE service_outputs SET operation_id='shop:buy'")
            with self.assertRaises(sqlite3.IntegrityError):
                con.execute("UPDATE inventory_rules SET capacity=60")

    def test_single_builder_registers_extension(self):
        import build_database as builder
        self.assertEqual(builder.TABLES.count("service_operations"), 1)
        self.assertEqual(builder.SCHEMA.count("CREATE TABLE service_operations("), 1)

    def test_training_art_owner_foreign_keys(self):
        import art_registry as art
        import build_database as builder
        path = "res://assets/town_v052/training-scarecrow.png"
        dimensions = list(struct.unpack(">II", art.local(db.ROOT, path).read_bytes()[16:24]))
        asset = {"id": "art:training:scarecrow", "category": "monster", "name": "training",
                 "path": path, "provenance": "game/assets/town_v052/PROVENANCE.md",
                 "catalog": "res://scripts/training_art.gd", "rect": [0, 0, *dimensions],
                 "frame": -1, "action": "stationary_training_target", "status": "applied",
                 "metadata": {"source_dimensions": dimensions}}
        raw = {"metadata": {}, "art_assets": [asset], "art_uses": [
            {"id": "training-use", "art_id": asset["id"], "target_table": "training_rules",
             "target_id": "training", "consumer": "game/scripts/training_art.gd:draw",
             "mapping": {}, "usage_kind": "runtime_mapping"}]}
        enriched = art.enrich(copy.deepcopy(raw), db.ROOT)
        self.assertEqual(enriched["art_files"][0]["width"], dimensions[0])
        bad = copy.deepcopy(raw)
        bad["art_assets"][0]["metadata"]["source_dimensions"] = [1, 1]
        with self.assertRaises(AssertionError): art.enrich(bad, db.ROOT)
        with sqlite3.connect(":memory:") as con:
            con.execute("PRAGMA foreign_keys=ON")
            con.executescript(builder.SCHEMA)
            db.insert(con, self.data)
            art.insert_sqlite(con, enriched)
            self.assertFalse(con.execute("PRAGMA foreign_key_check").fetchall())
            with self.assertRaises(sqlite3.IntegrityError):
                con.execute("UPDATE art_uses SET target_id='missing',training_rule_id='missing'")


if __name__ == "__main__": unittest.main()
