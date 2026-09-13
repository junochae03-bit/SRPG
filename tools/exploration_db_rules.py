"""Normalize exported exploration metadata; no engine or operational DB writes.

CPU checks: python -B tools/exploration_db_rules.py --self-test
The original catalog remains in metadata. generation_state describes provenance,
not gameplay implementation or a successful runtime test.
"""
from __future__ import annotations

import copy
import json
import sqlite3
from pathlib import Path

GENERATION_STATE = "metadata_projection"
TABLES = ["exploration_biomes", "exploration_materials", "exploration_acquisition",
          "crafting_recipes", "crafting_ingredients", "alchemy_recipes",
          "alchemy_inputs", "alchemy_outputs", "enhancement_bands", "enhancement_materials"]
SOURCES = {"catalog": "game/data/exploration_crafting_v071.json"}


def dump(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def indexed(rows):
    result = {r["id"]: r for r in rows}
    assert len(result) == len(rows), "duplicate normalized/source ID"
    return result


def relation_id(*parts):
    # JSON tuples cannot collide when source IDs themselves contain separators.
    return dump(parts)


def project(data):
    catalog = data["metadata"]["exploration_crafting"]
    result = {table: [] for table in TABLES}

    def append(table, row):
        result[table].append({**copy.deepcopy(row), "generation_state": GENERATION_STATE})

    for source, table in (("biomes", "exploration_biomes"), ("materials", "exploration_materials")):
        for key, row in catalog[source].items():
            assert row["id"] == key, f"mismatched {source} key"
            append(table, row)
    for row in catalog["acquisition"]:
        append("exploration_acquisition", row)
    base = catalog["recipes"]
    advanced = catalog["advanced_recipes"]
    assert not base.keys() & advanced.keys(), "base/advanced recipe collision"
    for key, row in {**base, **advanced}.items():
        assert key == row["id"], "mismatched crafting recipe key"
        append("crafting_recipes", row)
        for material, amount in row["materials"].items():
            append("crafting_ingredients", dict(id=relation_id(key, material), recipe_id=key,
                                                 material_id=material, amount=amount))
    production = data["metadata"]["production"]["recipes"]
    for key, row in catalog["alchemy_recipes"].items():
        assert key == row["id"] and key in production, "alchemy recipe absent from production export"
        # Do not silently advertise a design recipe that the production consumer changed.
        for field in ("name", "facility", "gold", "materials", "outputs", "seconds", "level", "research"):
            assert production[key][field] == row[field], f"production differs: {key}.{field}"
        append("alchemy_recipes", row)
        for source, table, column in (("materials", "alchemy_inputs", "material_id"),
                                       ("outputs", "alchemy_outputs", "item_id")):
            for item, amount in row[source].items():
                append(table, dict(id=relation_id(key, item), recipe_id=key,
                                   **{column: item}, amount=amount))
    policy = catalog["enhancement_materials"]
    runtime = policy["current_runtime_material_adapter"]
    for band in policy["bands"]:
        key = "enhancement:" + band["kind"]
        lo = max(band["target_min"], runtime["target_min"])
        hi = min(band["target_max"], runtime["target_max"])
        append("enhancement_bands", {**band, "id": key,
            "runtime_target_min": lo if lo <= hi else None,
            "runtime_target_max": hi if lo <= hi else None,
            "runtime_quantity_rule": runtime["quantity"], "runtime_gold_rule": runtime["gold"],
            "automatic_activation": policy["automatic_activation"]})
        for tier, material in band["material_by_tier"].items():
            append("enhancement_materials", dict(id=relation_id(key, tier), band_id=key,
                                                   tier=int(tier), material_id=material))
    return result


def enrich(data, root=None):
    projected = project(data)
    items = indexed(data["item_definitions"])
    for row in projected["exploration_materials"]:
        if row["id"] in items:
            assert items[row["id"]]["name"] == row["name"], "conflicting item display name"
        else:
            items[row["id"]] = {"id": row["id"], "name": row["name"], "generation_state": GENERATION_STATE}
    data["item_definitions"] = list(items.values())
    data.update(projected)
    data["metadata"]["schema_version"] = 6
    data["metadata"]["exploration_normalization"] = {
        "source": "metadata.exploration_crafting", "production_cross_check": "metadata.production.recipes",
        "generation_state": GENERATION_STATE, "runtime_tests_performed_by_projection": False,
        "enhancement_note": "user_confirmed_success_chance is a design value; runtime_target_min/max only project the current material-selection adapter, not probability activation",
        "counts": {table: len(rows) for table, rows in projected.items()},
    }
    return data


def validate(data):
    checks = 0

    def check(value, label):
        nonlocal checks
        checks += 1
        assert value, label

    tables = {name: indexed(data[name]) for name in TABLES}
    expected = project(data)
    for table in TABLES:
        check(tables[table] == indexed(expected[table]), f"lossless projection: {table}")
    biomes = tables["exploration_biomes"]
    mats = tables["exploration_materials"]
    equipment = indexed(data["equipment"])
    items = indexed(data["item_definitions"])
    facilities = indexed(data["facilities"])
    classes = indexed(data["classes"])
    floors = indexed(data["floors"])
    counts = data["metadata"]["exploration_crafting"]["metadata"]["counts"]
    for table, key in (("exploration_materials", "materials"), ("exploration_acquisition", "acquisition"),
                       ("crafting_recipes", "total_equipment_recipes"), ("alchemy_recipes", "alchemy_recipes"),
                       ("enhancement_bands", "enhancement_bands"), ("exploration_biomes", "biomes")):
        check(len(tables[table]) == counts[key], f"source count: {table}")
    for row in biomes.values():
        check(row["floor_min"] in floors and row["floor_max"] in floors, "biome floor references")
        check(all(floors[n]["tier"] == row["tier"] for n in range(row["floor_min"], row["floor_max"]+1)), "biome tier range")
    for row in mats.values():
        check(row["id"] in items and items[row["id"]]["name"] == row["name"], "material item definition")
        check(row["biome"] in biomes and biomes[row["biome"]]["tier"] == row["tier"], "material biome")
        check(0 <= row["rarity"] <= 4 and row["max_stack"] == row["stack"] > 0, "material grade and stack")
    for row in tables["exploration_acquisition"].values():
        material = mats[row["material_id"]]
        check((row["biome"], row["tier"]) == (material["biome"], material["tier"]), "drop biome")
        check(0 <= row["chance"] <= 1 and 0 < row["amount_min"] <= row["amount_max"] <= material["max_stack"], "drop bounds")
        biome = biomes[row["biome"]]
        check((row["floor_min"], row["floor_max"]) == (biome["floor_min"], biome["floor_max"]), "drop floor scope")
        if material["kind"] == "raid_seal":
            check(row["event"] == "raid_clear", "raid-only seal source")
    for row in tables["crafting_recipes"].values():
        item = equipment[row["existing_equipment_id"]]
        check((row["tier"], row["rarity"], row["slot"], row["job_lock"]) ==
              (item["tier"], item["rarity"], item["slot"], item["job_lock"]), "crafting equipment identity")
        check(row["job"] in classes and row["facility"] in facilities, "crafting owner/facility")
        check(row["amount"] > 0 and row["gold"] >= 0 and row["upgrade"] >= 0, "crafting amounts")
        if row["rarity"] > 1:
            check(any(mats[mid]["kind"] == "raid_seal" for mid in row["materials"]), "raid component required")
    for row in tables["alchemy_recipes"].values():
        check(row["facility"] in facilities and row["seconds"] > 0 and row["gold"] >= 0, "alchemy facility/cost")
        check(not any(mid in mats and mats[mid]["kind"] == "raid_seal" for mid in row["outputs"]), "seal cannot be manufactured")
    for table, parent, field in (("crafting_ingredients", "crafting_recipes", "material_id"),
                                  ("alchemy_inputs", "alchemy_recipes", "material_id"),
                                  ("alchemy_outputs", "alchemy_recipes", "item_id")):
        for row in tables[table].values():
            check(row["recipe_id"] in tables[parent], "recipe relationship")
            check(row[field] in (items if field == "item_id" else mats), "ingredient/output FK")
            check(type(row["amount"]) is int and row["amount"] > 0, "integer ingredient quantity")
    covered = []
    runtime_covered = []
    for row in tables["enhancement_bands"].values():
        covered.extend(range(row["target_min"], row["target_max"]+1))
        check(0 <= row["user_confirmed_success_chance"] <= 1, "design chance bounds")
        if row["runtime_target_min"] is not None:
            runtime_covered.extend(range(row["runtime_target_min"], row["runtime_target_max"]+1))
    policy = data["metadata"]["exploration_crafting"]["enhancement_materials"]
    adapter = policy["current_runtime_material_adapter"]
    check(len(covered) == len(set(covered)), "non-overlapping enhancement bands")
    check(sorted(runtime_covered) == list(range(adapter["target_min"], adapter["target_max"]+1)), "runtime material selection coverage")
    for row in tables["enhancement_materials"].values():
        band = tables["enhancement_bands"][row["band_id"]]
        check(mats[row["material_id"]]["tier"] == row["tier"], "enhancement material tier")
        check(mats[row["material_id"]]["kind"] == band["kind"], "enhancement material kind")
    check(data["metadata"]["exploration_normalization"]["generation_state"] == GENERATION_STATE, "truthful provenance")
    return checks


SCHEMA = """
PRAGMA user_version=6;
CREATE TABLE exploration_biomes(id TEXT PRIMARY KEY,name TEXT NOT NULL,tier INTEGER UNIQUE NOT NULL,floor_min INTEGER NOT NULL REFERENCES floors(id),floor_max INTEGER NOT NULL REFERENCES floors(id),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,CHECK(floor_min<=floor_max));
CREATE TABLE exploration_materials(id TEXT PRIMARY KEY REFERENCES item_definitions(id),name TEXT NOT NULL,biome TEXT NOT NULL REFERENCES exploration_biomes(id),tier INTEGER NOT NULL,rarity INTEGER NOT NULL REFERENCES rarities(id),kind TEXT NOT NULL,max_stack INTEGER NOT NULL CHECK(max_stack>0),icon TEXT NOT NULL,binding TEXT NOT NULL,sell_gold INTEGER NOT NULL CHECK(sell_gold>=0),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,UNIQUE(id,biome,tier),UNIQUE(id,tier));
CREATE TABLE exploration_acquisition(id TEXT PRIMARY KEY,material_id TEXT NOT NULL,biome TEXT NOT NULL REFERENCES exploration_biomes(id),tier INTEGER NOT NULL,event TEXT NOT NULL,floor_min INTEGER NOT NULL REFERENCES floors(id),floor_max INTEGER NOT NULL REFERENCES floors(id),chance REAL NOT NULL CHECK(chance BETWEEN 0 AND 1),amount_min INTEGER NOT NULL CHECK(amount_min>0),amount_max INTEGER NOT NULL CHECK(amount_max>=amount_min),recipient TEXT NOT NULL,roll_mode TEXT NOT NULL,risk_bonus INTEGER NOT NULL CHECK(risk_bonus IN (0,1)),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,FOREIGN KEY(material_id,biome,tier) REFERENCES exploration_materials(id,biome,tier),CHECK(floor_min<=floor_max));
CREATE TABLE crafting_recipes(id TEXT PRIMARY KEY,name TEXT NOT NULL,existing_equipment_id TEXT NOT NULL REFERENCES equipment(id),job TEXT NOT NULL REFERENCES classes(id),facility TEXT NOT NULL REFERENCES facilities(id),tier INTEGER NOT NULL,rarity INTEGER NOT NULL REFERENCES rarities(id),level INTEGER NOT NULL CHECK(level>=0),gold INTEGER NOT NULL CHECK(gold>=0),upgrade INTEGER NOT NULL CHECK(upgrade>=0),amount INTEGER NOT NULL CHECK(amount>0),affix TEXT NOT NULL,success_chance REAL NOT NULL CHECK(success_chance BETWEEN 0 AND 1),craft_seconds REAL NOT NULL CHECK(craft_seconds>=0),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL);
CREATE TABLE crafting_ingredients(id TEXT PRIMARY KEY,recipe_id TEXT NOT NULL REFERENCES crafting_recipes(id),material_id TEXT NOT NULL REFERENCES exploration_materials(id),amount INTEGER NOT NULL CHECK(amount>0 AND typeof(amount)='integer'),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,UNIQUE(recipe_id,material_id));
CREATE TABLE alchemy_recipes(id TEXT PRIMARY KEY,name TEXT NOT NULL,facility TEXT NOT NULL REFERENCES facilities(id),biome TEXT NOT NULL REFERENCES exploration_biomes(id),level INTEGER NOT NULL CHECK(level>=0),gold INTEGER NOT NULL CHECK(gold>=0),seconds REAL NOT NULL CHECK(seconds>0),success_chance REAL NOT NULL CHECK(success_chance BETWEEN 0 AND 1),research TEXT NOT NULL,icon TEXT NOT NULL,generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL);
CREATE TABLE alchemy_inputs(id TEXT PRIMARY KEY,recipe_id TEXT NOT NULL REFERENCES alchemy_recipes(id),material_id TEXT NOT NULL REFERENCES exploration_materials(id),amount INTEGER NOT NULL CHECK(amount>0 AND typeof(amount)='integer'),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,UNIQUE(recipe_id,material_id));
CREATE TABLE alchemy_outputs(id TEXT PRIMARY KEY,recipe_id TEXT NOT NULL REFERENCES alchemy_recipes(id),item_id TEXT NOT NULL REFERENCES item_definitions(id),amount INTEGER NOT NULL CHECK(amount>0 AND typeof(amount)='integer'),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,UNIQUE(recipe_id,item_id));
CREATE TABLE enhancement_bands(id TEXT PRIMARY KEY,kind TEXT UNIQUE NOT NULL,target_min INTEGER NOT NULL CHECK(target_min>0),target_max INTEGER NOT NULL CHECK(target_max>=target_min),user_confirmed_success_chance REAL NOT NULL CHECK(user_confirmed_success_chance BETWEEN 0 AND 1),runtime_target_min INTEGER,runtime_target_max INTEGER,runtime_quantity_rule TEXT NOT NULL,runtime_gold_rule TEXT NOT NULL,automatic_activation INTEGER NOT NULL CHECK(automatic_activation IN (0,1)),generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,CHECK((runtime_target_min IS NULL AND runtime_target_max IS NULL) OR (runtime_target_min IS NOT NULL AND runtime_target_max IS NOT NULL AND runtime_target_min>=target_min AND runtime_target_max<=target_max AND runtime_target_min<=runtime_target_max)));
CREATE TABLE enhancement_materials(id TEXT PRIMARY KEY,band_id TEXT NOT NULL REFERENCES enhancement_bands(id),tier INTEGER NOT NULL,material_id TEXT NOT NULL,generation_state TEXT NOT NULL CHECK(generation_state='metadata_projection'),definition_json TEXT NOT NULL,UNIQUE(band_id,tier),FOREIGN KEY(material_id,tier) REFERENCES exploration_materials(id,tier));
CREATE INDEX exploration_drop_search ON exploration_acquisition(material_id,event,floor_min,floor_max);
CREATE INDEX exploration_material_grade ON exploration_materials(rarity,biome,kind);
CREATE INDEX crafting_output_search ON crafting_recipes(existing_equipment_id,rarity);
CREATE INDEX crafting_material_search ON crafting_ingredients(material_id,recipe_id);
CREATE INDEX alchemy_input_search ON alchemy_inputs(material_id,recipe_id);
CREATE INDEX alchemy_output_search ON alchemy_outputs(item_id,recipe_id);
CREATE INDEX enhancement_target_search ON enhancement_bands(target_min,target_max);
CREATE VIEW exploration_material_usage AS
 SELECT material_id,'equipment' usage,recipe_id reference_id,amount FROM crafting_ingredients
 UNION ALL SELECT material_id,'alchemy',recipe_id,amount FROM alchemy_inputs
 UNION ALL SELECT material_id,'enhancement_selection',band_id,NULL FROM enhancement_materials;
"""

COLUMNS = {
    "exploration_biomes": "id name tier floor_min floor_max",
    "exploration_materials": "id name biome tier rarity kind max_stack icon binding sell_gold",
    "exploration_acquisition": "id material_id biome tier event floor_min floor_max chance amount_min amount_max recipient roll_mode risk_bonus",
    "crafting_recipes": "id name existing_equipment_id job facility tier rarity level gold upgrade amount affix success_chance craft_seconds",
    "crafting_ingredients": "id recipe_id material_id amount",
    "alchemy_recipes": "id name facility biome level gold seconds success_chance research icon",
    "alchemy_inputs": "id recipe_id material_id amount",
    "alchemy_outputs": "id recipe_id item_id amount",
    "enhancement_bands": "id kind target_min target_max user_confirmed_success_chance runtime_target_min runtime_target_max runtime_quantity_rule runtime_gold_rule automatic_activation",
    "enhancement_materials": "id band_id tier material_id",
}


def insert(con, data):
    for table in TABLES:
        columns = COLUMNS[table].split() + ["generation_state"]
        sql = f"INSERT INTO {table} ({','.join(columns)},definition_json) VALUES ({','.join('?' for _ in range(len(columns)+1))})"
        con.executemany(sql, [[row[c] for c in columns] + [dump(row)] for row in data[table]])


def self_test():
    """Read a snapshot; validate a private in-memory projection and real SQL FKs."""
    import build_database
    root = Path(__file__).resolve().parents[1]
    data = json.loads((root / "docs/database/stelrpg-database.json").read_text("utf-8"))
    old_meta = copy.deepcopy(data["metadata"])
    old_items = indexed(copy.deepcopy(data["item_definitions"]))
    data = build_database.canonical(enrich(data))
    checks = validate(data)
    assert all(data["metadata"][key] == value for key, value in old_meta.items()
               if key not in ("schema_version", "exploration_normalization"))
    assert all(indexed(data["item_definitions"])[key] == row for key, row in old_items.items())
    assert enrich(copy.deepcopy(data)) == data, "idempotent enrichment"
    con = sqlite3.connect(":memory:")
    con.executescript("PRAGMA foreign_keys=ON; CREATE TABLE floors(id INTEGER PRIMARY KEY); CREATE TABLE rarities(id INTEGER PRIMARY KEY); CREATE TABLE equipment(id TEXT PRIMARY KEY); CREATE TABLE classes(id TEXT PRIMARY KEY); CREATE TABLE facilities(id TEXT PRIMARY KEY); CREATE TABLE item_definitions(id TEXT PRIMARY KEY,name TEXT NOT NULL);")
    for table in ("floors", "equipment", "classes", "facilities"):
        con.executemany(f"INSERT INTO {table} VALUES (?)", [(r["id"],) for r in data[table]])
    con.executemany("INSERT INTO rarities VALUES (?)", [(i,) for i in range(5)])
    con.executemany("INSERT INTO item_definitions VALUES (?,?)", [(r["id"],r["name"]) for r in data["item_definitions"]])
    con.executescript(SCHEMA)
    insert(con, data)
    assert not con.execute("PRAGMA foreign_key_check").fetchall()
    assert con.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    for table in TABLES:
        actual = indexed([json.loads(r[0]) for r in con.execute(f"SELECT definition_json FROM {table}")])
        assert actual == indexed(data[table]), f"SQL round-trip {table}"
    assert con.execute("SELECT count(DISTINCT material_id) FROM exploration_material_usage").fetchone()[0] == len(data["exploration_materials"])
    assert con.execute("SELECT count(*) FROM crafting_recipes WHERE rarity=4").fetchone()[0] == 500
    # Real constraint failures: dangling FK, invalid amounts/chance, cross-tier material,
    # duplicate relation, and false provenance must never reach an output snapshot.
    failures = [
        "UPDATE crafting_ingredients SET material_id='missing' WHERE rowid=1",
        "UPDATE crafting_ingredients SET amount=0 WHERE rowid=1",
        "UPDATE crafting_ingredients SET amount=0.5 WHERE rowid=1",
        "UPDATE exploration_acquisition SET chance=1.1 WHERE rowid=1",
        "UPDATE enhancement_materials SET tier=99 WHERE rowid=1",
        "UPDATE alchemy_outputs SET item_id='missing' WHERE rowid=1",
        "UPDATE crafting_recipes SET existing_equipment_id='missing' WHERE rowid=1",
        "UPDATE enhancement_bands SET runtime_target_max=99 WHERE rowid=1",
        "UPDATE exploration_materials SET generation_state='runtime_verified' WHERE rowid=1",
        "INSERT INTO crafting_ingredients SELECT * FROM crafting_ingredients LIMIT 1",
    ]
    for sql in failures:
        con.execute("SAVEPOINT invalid_case")
        try:
            con.execute(sql)
        except sqlite3.IntegrityError:
            pass
        else:
            raise AssertionError("SQL accepted invalid data: " + sql)
        finally:
            con.execute("ROLLBACK TO invalid_case")
            con.execute("RELEASE invalid_case")
    # Mismatched evaluated production must fail before writing SQL.
    broken = copy.deepcopy(data)
    key = next(iter(broken["metadata"]["exploration_crafting"]["alchemy_recipes"]))
    broken["metadata"]["production"]["recipes"][key]["gold"] += 1
    try:
        enrich(broken)
    except AssertionError:
        pass
    else:
        raise AssertionError("production mismatch accepted")
    # Exercise the actual full builder schema/insertion without writing a database file.
    build_database.build_sqlite(":memory:", data)
    print(dump({"status": "PASS", "checks": checks, "negative_sql_cases": len(failures),
                "production_mismatch_rejected": True, "full_sql_builder": "in_memory_pass",
                "counts": {t: len(data[t]) for t in TABLES}, "item_definitions": len(data["item_definitions"]),
                "engine_run": False, "operational_database_written": False}))


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", required=True)
    parser.parse_args()
    self_test()
