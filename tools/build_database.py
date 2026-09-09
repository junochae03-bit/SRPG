"""Generate and verify a portable encyclopedia DB from the actual Godot model.

GODOT_EXE=<Godot 4.6> python tools/build_database.py [--check]
Uses only the Python standard library. No game save is read or modified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import subprocess
import tempfile
from pathlib import Path

from engine_path import engine, hidden_options
import art_registry
import game_db_rules

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/database"
TABLES = ["classes", "equipment", "monsters", "raids", "floors", "appearances", "drops", "raid_drops", "skills", "skill_parents", "skill_ranks", "build_nodes", "constellations", "constellation_edges", "exclusive_groups", "effect_definitions", "constellation_effects", "constellation_exclusions"]
TABLES += art_registry.TABLES
TABLES += game_db_rules.TABLES
RELATIONS = {"skill_parents", "skill_ranks", "constellation_edges", "constellation_effects", "constellation_exclusions"}


def dumps(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def canonical(value):
    if isinstance(value, dict):
        return {k: canonical(v) for k, v in sorted(value.items())}
    if isinstance(value, list):
        return [canonical(v) for v in value]
    if isinstance(value, float):
        value = round(value, 9)
        return int(value) if value.is_integer() else value
    return value


def normalize(data):
    data = game_db_rules.enrich(data, ROOT)
    data = art_registry.enrich(data, ROOT)
    data = canonical(data)
    for skill in data["skills"] + data["constellations"]:
        skill.pop("ranks", None)  # canonical relational skill_ranks already contains them
        skill.pop("node", None)  # node metadata already lives on this skill row
    for rank in data["skill_ranks"]:
        node = rank["profile"].get("node")
        if node:
            rank["profile"]["node"] = {k: v for k, v in node.items() if k in ("mode", "radius", "range", "duration", "distance", "rune_cost", "element", "cost", "windup")}
    for table in TABLES:
        data[table].sort(key=lambda r: (str(r.get("id", r.get("skill_id", r.get("node_id", r.get("left_id", ""))))), str(r.get("parent_id", r.get("effect_id", r.get("right_id", "")))), int(r.get("rank", 0))))
    # Follow script/data dependencies and used texture paths; source edits or art
    # region edits invalidate a snapshot even if display text happens to match.
    todo = [ROOT / "game/scripts/game_database.gd", Path(__file__).resolve(), Path(art_registry.__file__).resolve(), Path(game_db_rules.__file__).resolve()]
    todo += [ROOT / path for path in game_db_rules.SOURCES.values()]
    todo += [art_registry.local(ROOT, row["path"]) for table in ("art_files", "art_sources") for row in data[table]]
    todo += [art_registry.local(ROOT, catalog) for catalog in sorted({row["catalog"] for row in data["art_assets"]})]
    consumers = {row["consumer"].split(":", 1)[0] if not row["consumer"].startswith("res://") else row["consumer"] for row in data["art_uses"]}
    todo += [art_registry.local(ROOT, consumer) for consumer in sorted(consumers)]
    for table in TABLES:
        for row in data[table]:
            if row.get("asset", {}).get("path", "").startswith("res://"):
                todo.append(ROOT / "game" / row["asset"]["path"][6:])
    hashes = {}
    while todo:
        path = todo.pop().resolve()
        name = path.relative_to(ROOT).as_posix()
        if name in hashes or not path.is_file():
            continue
        blob = path.read_bytes()
        hashes[name] = hashlib.sha256(blob).hexdigest()
        if path.suffix in (".gd", ".json"):
            for ref in re.findall(r'res://([^\s"\']+\.(?:gd|json|png|gdshader))', blob.decode("utf8")):
                todo.append(ROOT / "game" / ref)
    data["metadata"]["source_sha256"] = dict(sorted(hashes.items()))
    data["metadata"]["counts"] = {table: len(data[table]) for table in TABLES}
    data["metadata"]["equipment_note"] = "2,500 rows describe slot/owner/tier/grade combinations at +0. affix/resonance fields are representative, not guaranteed rolls."
    return data


def validate(data):
    game_db_rules.validate(data)
    art_registry.validate(data, ROOT)
    assert len(data["classes"]) == 20
    assert len(data["equipment"]) == 2500
    assert len(data["monsters"]) == 24
    assert len(data["raids"]) == 10
    assert len(data["floors"]) == 100
    assert len(data["skills"]) == 610
    assert len(data["constellations"]) == 900
    assert len(data["build_nodes"]) == 1510
    indexes = {}
    for table in TABLES:
        if table in RELATIONS:
            continue
        rows = data[table]
        indexes[table] = {r["id"]: r for r in rows}
        assert len(indexes[table]) == len(rows), f"Duplicate {table} ID"
    classes = indexes["classes"]
    skills = indexes["skills"]
    rank_keys = set()
    for row in data["equipment"]:
        assert 0 <= row["tier"] <= 9 and 0 <= row["rarity"] <= 4
        assert row["option_unlock"] == [0, 2, 3, 4, 5][row["rarity"]]
        assert row["family"] in classes and classes[row["family"]]["family"] == row["family"]
        if row["slot"] == "weapon":
            assert classes[row["job_lock"]]["family"] == row["family"]
        else:
            assert row["job_lock"] == ""
    for table in ("drops", "raid_drops"):
        for row in data[table]:
            assert 0 <= row["chance"] <= 1 and row["amount"] >= 1
            assert row["monster_id"] in indexes["monsters"]
    assert all(r["rarity"] <= 2 for r in data["drops"]), "Epic+ belongs only to raids"
    for raid in data["raids"]:
        assert raid["floor"] % 10 == 0
        rows = [r for r in data["raid_drops"] if r["raid_id"] == raid["id"]]
        assert abs(sum(r["chance"] for r in rows) - 1) < 1e-8
        assert all(r["amount"] == 1 and r["roll_mode"] == "guaranteed_extra_conditional_grade" for r in rows)
    parent_keys = set()
    for edge in data["skill_parents"]:
        pair = (edge["skill_id"], edge["parent_id"])
        assert pair not in parent_keys
        parent_keys.add(pair)
        assert skills[pair[0]]["class_id"] == skills[pair[1]]["class_id"]
        assert 1 <= edge["required_rank"] <= skills[pair[1]]["max_rank"]
    for rank in data["skill_ranks"]:
        pair = (rank["skill_id"], rank["rank"])
        assert pair not in rank_keys
        rank_keys.add(pair)
        assert 1 <= pair[1] <= skills[pair[0]]["max_rank"]
        assert rank["stagger"]["value"] >= 0 and rank["stagger"]["multiplier"] >= 1
    assert len(rank_keys) == sum(s["max_rank"] for s in data["skills"])
    build_nodes = indexes["build_nodes"]
    for c in classes:
        nodes = [n for n in data["constellations"] if n["class_id"] == c]
        assert len(nodes) == 45
        assert sum(n["type"] == "minor" for n in nodes) == 30
        assert sum(n["type"] == "notable" for n in nodes) == 10
        assert sum(n["type"] == "keystone" for n in nodes) == 5
    for row in data["constellations"]:
        assert row["id"] in build_nodes
        assert row["cost"] == {"minor": 1, "notable": 3, "keystone": 6}[row["type"]]
        assert row["max_rank"] == 1
        assert row["effects"] and row["effects_text"]
        if row["type"] in ("keystone", "notable"):
            assert row["tradeoff"] and row["synergy"]
    for edge in data["constellation_edges"]:
        assert edge["node_id"] in indexes["constellations"]
        assert build_nodes[edge["node_id"]]["class_id"] == build_nodes[edge["parent_id"]]["class_id"]
        assert edge["mode"] in ("any", "all")
    for effect in data["constellation_effects"]:
        assert effect["node_id"] in indexes["constellations"]
        assert effect["effect_id"] in indexes["effect_definitions"]
        assert effect["value"] > 0
    assert data["metadata"]["build_policy"]["max_keystones"] == 2
    for pair in data["constellation_exclusions"]:
        assert pair["left_id"] < pair["right_id"]
        assert build_nodes[pair["left_id"]]["class_id"] == build_nodes[pair["right_id"]]["class_id"]
    for appearance in data["appearances"]:
        assert appearance["floor_id"] in indexes["floors"]
        assert appearance["monster_id"] in indexes["monsters"]
        assert appearance["health"] > 0 and appearance["damage"] > 0
    for table in TABLES:
        for row in data[table]:
            asset = row.get("asset")
            if asset:
                assert asset["path"].startswith("res://")
                assert (ROOT / "game" / asset["path"][6:]).is_file(), asset
                assert len(asset["rect"]) == 4 and min(asset["rect"][2:]) > 0


SCHEMA = """
PRAGMA foreign_keys=ON;
PRAGMA user_version=2;
CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE families(id TEXT PRIMARY KEY,name TEXT NOT NULL);
CREATE TABLE classes(id TEXT PRIMARY KEY,name TEXT NOT NULL,family_id TEXT NOT NULL REFERENCES families(id),base_class_id TEXT REFERENCES classes(id),description TEXT NOT NULL,weapon TEXT NOT NULL);
CREATE TABLE assets(id TEXT PRIMARY KEY,path TEXT NOT NULL,x REAL NOT NULL,y REAL NOT NULL,width REAL NOT NULL CHECK(width>0),height REAL NOT NULL CHECK(height>0),metadata_json TEXT NOT NULL);
CREATE TABLE rarities(id INTEGER PRIMARY KEY CHECK(id BETWEEN 0 AND 4),name TEXT NOT NULL,color TEXT NOT NULL,option_unlock INTEGER NOT NULL);
CREATE TABLE equipment(id TEXT PRIMARY KEY,name TEXT NOT NULL,family_id TEXT NOT NULL REFERENCES families(id),class_id TEXT REFERENCES classes(id),slot TEXT NOT NULL,tier INTEGER NOT NULL CHECK(tier BETWEEN 0 AND 9),rarity INTEGER NOT NULL REFERENCES rarities(id),required_level INTEGER NOT NULL,bonus INTEGER NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),option_summary TEXT NOT NULL);
CREATE UNIQUE INDEX equipment_combination ON equipment(family_id,COALESCE(class_id,''),slot,tier,rarity);
CREATE TABLE monsters(id TEXT PRIMARY KEY,name TEXT NOT NULL,role TEXT NOT NULL,health INTEGER NOT NULL,damage INTEGER NOT NULL,speed REAL NOT NULL,attack_range REAL NOT NULL,xp INTEGER NOT NULL,gold INTEGER NOT NULL,ai TEXT NOT NULL,display_height REAL NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),patterns_json TEXT NOT NULL,stagger_json TEXT NOT NULL);
CREATE TABLE floors(id INTEGER PRIMARY KEY CHECK(id BETWEEN 1 AND 100),name TEXT NOT NULL,level INTEGER NOT NULL,required_level INTEGER NOT NULL,tier INTEGER NOT NULL,terrain TEXT NOT NULL,guardian_id TEXT NOT NULL REFERENCES monsters(id),is_raid INTEGER NOT NULL,lore TEXT NOT NULL);
CREATE TABLE raids(id TEXT PRIMARY KEY,floor_id INTEGER UNIQUE NOT NULL REFERENCES floors(id),monster_id TEXT NOT NULL REFERENCES monsters(id),name TEXT NOT NULL,health INTEGER NOT NULL,damage INTEGER NOT NULL,xp INTEGER NOT NULL,gold INTEGER NOT NULL,patterns_json TEXT NOT NULL,stagger_json TEXT NOT NULL);
CREATE TABLE appearances(id TEXT PRIMARY KEY,floor_id INTEGER NOT NULL REFERENCES floors(id),monster_id TEXT NOT NULL REFERENCES monsters(id),role TEXT NOT NULL,raid_id TEXT REFERENCES raids(id),level INTEGER NOT NULL,health INTEGER NOT NULL,damage INTEGER NOT NULL,xp INTEGER NOT NULL,gold INTEGER NOT NULL,speed REAL NOT NULL);
CREATE TABLE drops(id TEXT PRIMARY KEY,monster_id TEXT NOT NULL REFERENCES monsters(id),entry_key TEXT NOT NULL,name TEXT NOT NULL,kind TEXT NOT NULL,slot TEXT,rarity INTEGER NOT NULL REFERENCES rarities(id),chance REAL NOT NULL CHECK(chance BETWEEN 0 AND 1),amount INTEGER NOT NULL CHECK(amount>0),roll_mode TEXT NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),entry_json TEXT NOT NULL,UNIQUE(monster_id,entry_key));
CREATE TABLE raid_drops(id TEXT PRIMARY KEY,raid_id TEXT NOT NULL REFERENCES raids(id),rarity INTEGER NOT NULL REFERENCES rarities(id),chance REAL NOT NULL CHECK(chance BETWEEN 0 AND 1),slot_probability REAL NOT NULL CHECK(slot_probability BETWEEN 0 AND 1),amount INTEGER NOT NULL CHECK(amount=1),tier INTEGER NOT NULL,roll_mode TEXT NOT NULL,UNIQUE(raid_id,rarity));
CREATE TABLE skills(id TEXT PRIMARY KEY,class_id TEXT NOT NULL REFERENCES classes(id),name TEXT NOT NULL,effect TEXT NOT NULL,max_rank INTEGER NOT NULL,required_level INTEGER NOT NULL,parent_mode TEXT NOT NULL,target_id TEXT REFERENCES skills(id),description TEXT NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),node_json TEXT NOT NULL);
CREATE TABLE skill_parents(skill_id TEXT NOT NULL REFERENCES skills(id),parent_id TEXT NOT NULL REFERENCES skills(id),required_rank INTEGER NOT NULL,mode TEXT NOT NULL,PRIMARY KEY(skill_id,parent_id));
CREATE TABLE skill_ranks(skill_id TEXT NOT NULL REFERENCES skills(id),rank INTEGER NOT NULL CHECK(rank>0),metrics_json TEXT NOT NULL,profile_json TEXT NOT NULL,stagger_base REAL NOT NULL CHECK(stagger_base>=0),stagger_value REAL NOT NULL CHECK(stagger_value>=0),stagger_grade TEXT NOT NULL,stagger_multiplier REAL NOT NULL CHECK(stagger_multiplier>=1),PRIMARY KEY(skill_id,rank));
CREATE TABLE exclusive_groups(id TEXT PRIMARY KEY,class_id TEXT NOT NULL REFERENCES classes(id),max_selected INTEGER NOT NULL CHECK(max_selected=1));
CREATE TABLE build_nodes(id TEXT PRIMARY KEY,class_id TEXT NOT NULL REFERENCES classes(id),type TEXT NOT NULL CHECK(type IN ('original','minor','notable','keystone')),cost INTEGER NOT NULL CHECK(cost>0),max_rank INTEGER NOT NULL CHECK(max_rank>0),required_level INTEGER NOT NULL,exclusive_group TEXT REFERENCES exclusive_groups(id));
CREATE TABLE constellations(id TEXT PRIMARY KEY REFERENCES build_nodes(id),name TEXT NOT NULL,cluster INTEGER NOT NULL CHECK(cluster BETWEEN 0 AND 4),cluster_name TEXT NOT NULL,description TEXT NOT NULL,effects_text TEXT NOT NULL,synergy TEXT NOT NULL,tradeoff TEXT NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),node_json TEXT NOT NULL);
CREATE TABLE constellation_edges(node_id TEXT NOT NULL REFERENCES constellations(id),parent_id TEXT NOT NULL REFERENCES build_nodes(id),required_rank INTEGER NOT NULL CHECK(required_rank>0),mode TEXT NOT NULL CHECK(mode IN ('any','all')),PRIMARY KEY(node_id,parent_id));
CREATE TABLE effect_definitions(id TEXT PRIMARY KEY,name TEXT NOT NULL);
CREATE TABLE constellation_effects(node_id TEXT NOT NULL REFERENCES constellations(id),effect_id TEXT NOT NULL REFERENCES effect_definitions(id),value REAL NOT NULL,PRIMARY KEY(node_id,effect_id));
CREATE TABLE constellation_exclusions(left_id TEXT NOT NULL REFERENCES constellations(id),right_id TEXT NOT NULL REFERENCES constellations(id),PRIMARY KEY(left_id,right_id),CHECK(left_id<right_id));
CREATE VIEW build_edges AS SELECT skill_id node_id,parent_id,required_rank,mode FROM skill_parents UNION ALL SELECT node_id,parent_id,required_rank,mode FROM constellation_edges;
CREATE INDEX appearances_by_monster ON appearances(monster_id,floor_id);
CREATE INDEX drops_by_slot_rarity ON drops(slot,rarity);
CREATE INDEX skills_by_class ON skills(class_id,effect);
CREATE VIEW equipment_dungeon_sources AS
 SELECT DISTINCT e.id equipment_id,d.id drop_id,a.floor_id,d.monster_id,d.chance,'independent_per_entry' probability_kind
 FROM equipment e JOIN drops d ON d.slot=e.slot AND d.rarity=e.rarity
 JOIN appearances a ON a.monster_id=d.monster_id JOIN floors f ON f.id=a.floor_id AND f.tier=e.tier;
CREATE VIEW equipment_raid_sources AS
 SELECT e.id equipment_id,d.id drop_id,r.floor_id,r.monster_id,d.chance grade_chance,d.slot_probability,d.chance*d.slot_probability joint_slot_chance
 FROM equipment e JOIN raid_drops d ON d.rarity=e.rarity AND d.tier=e.tier JOIN raids r ON r.id=d.raid_id;
"""


SCHEMA += art_registry.SCHEMA
SCHEMA += game_db_rules.SCHEMA


def build_sqlite(path, data):
    con = sqlite3.connect(path)
    con.executescript(SCHEMA)
    con.execute("PRAGMA defer_foreign_keys=ON")
    con.executemany("INSERT INTO metadata VALUES (?,?)", [(k, dumps(v)) for k, v in sorted(data["metadata"].items())])
    for c in data["classes"]:
        if c["id"] == c["family"]:
            con.execute("INSERT INTO families VALUES (?,?)", (c["id"], c["family_name"]))
    for c in data["classes"]:
        con.execute("INSERT INTO classes VALUES (?,?,?,?,?,?)", (c["id"], c["name"], c["family"], c.get("base"), c["description"], c["weapon"]))
    assets = {}
    for table in TABLES:
        for row in data[table]:
            if "asset" in row:
                key = dumps(row["asset"])
                aid = hashlib.sha256(key.encode()).hexdigest()[:20]
                assets[key] = aid
    for key, aid in sorted(assets.items()):
        a = json.loads(key)
        con.execute("INSERT INTO assets VALUES (?,?,?,?,?,?,?)", (aid, a["path"], *a["rect"], dumps({k: v for k, v in a.items() if k not in ("path", "rect")})))
    asset_id = lambda row: assets[dumps(row["asset"])]
    for grade in range(5):
        e = next(r for r in data["equipment"] if r["rarity"] == grade)
        con.execute("INSERT INTO rarities VALUES (?,?,?,?)", (grade, e["grade_name"], e["grade_color"], e["option_unlock"]))
    for r in data["equipment"]:
        con.execute("INSERT INTO equipment VALUES (?,?,?,?,?,?,?,?,?,?,?)", (r["id"], r["name"], r["family"], r["job_lock"] or None, r["slot"], r["tier"], r["rarity"], r["required_level"], r["bonus"], asset_id(r), r["option_summary"]))
    for r in data["monsters"]:
        con.execute("INSERT INTO monsters VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", (r["id"], r["name"], r["role"], r["health"], r["damage"], r["speed"], r["range"], r["xp"], r["gold"], r["ai"], r["display_height"], asset_id(r), dumps(r["patterns"]), dumps(r.get("stagger", {}))))
    for r in data["floors"]:
        con.execute("INSERT INTO floors VALUES (?,?,?,?,?,?,?,?,?)", (r["id"], r["name"], r["level"], r["required_level"], r["tier"], r["terrain"], r["guardian_id"], int(r["raid"]), r["lore"]))
    for r in data["raids"]:
        con.execute("INSERT INTO raids VALUES (?,?,?,?,?,?,?,?,?,?)", (r["id"], r["floor"], r["monster_id"], r["name"], r["health"], r["damage"], r["xp"], r["gold"], dumps(r["patterns"]), dumps(r["stagger"])))
    for r in data["appearances"]:
        con.execute("INSERT INTO appearances VALUES (?,?,?,?,?,?,?,?,?,?,?)", (r["id"], r["floor_id"], r["monster_id"], r["role"], r["raid_id"] or None, r["level"], r["health"], r["damage"], r["xp"], r["gold"], r["speed"]))
    for r in data["drops"]:
        con.execute("INSERT INTO drops VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (r["id"], r["monster_id"], r["key"], r["name"], r["kind"], r["slot"] or None, r["rarity"], r["chance"], r["amount"], r["roll_mode"], asset_id(r), dumps({k: v for k, v in r.items() if k in ("weapon", "weapons", "material")}),))
    for r in data["raid_drops"]:
        con.execute("INSERT INTO raid_drops VALUES (?,?,?,?,?,?,?,?)", (r["id"], r["raid_id"], r["rarity"], r["chance"], r["slot_probability"], r["amount"], r["tier"], r["roll_mode"]))
    for r in data["skills"]:
        con.execute("INSERT INTO skills VALUES (?,?,?,?,?,?,?,?,?,?,?)", (r["id"], r["class_id"], r["name"], r["effect"], r["max_rank"], r.get("level", 1), r.get("parent_mode", "any"), r.get("target"), r["description"], asset_id(r), dumps({k: v for k, v in r.items() if k not in ("asset", "subtitle")})))
    for r in data["skill_parents"]:
        con.execute("INSERT INTO skill_parents VALUES (?,?,?,?)", (r["skill_id"], r["parent_id"], r["required_rank"], r["mode"]))
    for r in data["skill_ranks"]:
        s = r["stagger"]
        con.execute("INSERT INTO skill_ranks VALUES (?,?,?,?,?,?,?,?)", (r["skill_id"], r["rank"], dumps(r["metrics"]), dumps(r["profile"]), s["base"], s["value"], s["grade"], s["multiplier"]))
    for r in data["exclusive_groups"]:
        con.execute("INSERT INTO exclusive_groups VALUES (?,?,?)", (r["id"], r["class_id"], r["max_selected"]))
    for r in data["build_nodes"]:
        con.execute("INSERT INTO build_nodes VALUES (?,?,?,?,?,?,?)", (r["id"], r["class_id"], r["type"], r["cost"], r["max_rank"], r["required_level"], r["exclusive_group"] or None))
    for r in data["constellations"]:
        con.execute("INSERT INTO constellations VALUES (?,?,?,?,?,?,?,?,?,?)", (r["id"], r["name"], r["cluster"], r["cluster_name"], r["description"], r["effects_text"], r["synergy"], r["tradeoff"], asset_id(r), dumps({k: v for k, v in r.items() if k not in ("asset", "subtitle")})))
    for r in data["constellation_edges"]:
        con.execute("INSERT INTO constellation_edges VALUES (?,?,?,?)", (r["node_id"], r["parent_id"], r["required_rank"], r["mode"]))
    for r in data["effect_definitions"]:
        con.execute("INSERT INTO effect_definitions VALUES (?,?)", (r["id"], r["name"]))
    for r in data["constellation_effects"]:
        con.execute("INSERT INTO constellation_effects VALUES (?,?,?)", (r["node_id"], r["effect_id"], r["value"]))
    for r in data["constellation_exclusions"]:
        con.execute("INSERT INTO constellation_exclusions VALUES (?,?)", (r["left_id"], r["right_id"]))
    art_registry.insert_sqlite(con, data)
    game_db_rules.insert(con, data)
    assert not con.execute("PRAGMA foreign_key_check").fetchall()
    con.commit()
    assert con.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    con.execute("VACUUM")
    con.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="rebuild in a temporary directory and reject stale JSON/SQLite/schema")
    args = parser.parse_args()
    (ROOT / "runtime").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="database-", dir=ROOT / "runtime") as temporary:
        tmp = Path(temporary)
        source = tmp / "live.json"
        command = [engine(), "--headless", "--path", str(ROOT / "game"), "--script", "res://tests/export_database.gd", "--", "--output=" + str(source)]
        run = subprocess.run(command, capture_output=True, text=True, encoding="utf8", errors="replace", timeout=90, **hidden_options())
        log = run.stdout + run.stderr
        (ROOT / "runtime/database-build.log").write_text(log, encoding="utf8")
        if run.returncode or "ERROR:" in log or "SCRIPT ERROR" in log:
            raise RuntimeError(log[-6000:])
        data = normalize(json.loads(source.read_text("utf8")))
        validate(data)
        output_json = tmp / "stelrpg-database.json"
        output_json.write_text(json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n", "utf8")
        output_db = tmp / "stelrpg.sqlite"
        build_sqlite(output_db, data)
        schema_file = tmp / "schema.sql"
        schema_file.write_text(SCHEMA.strip() + "\n", "utf8")
        files = [output_json, output_db, schema_file]
        manifest = {"schema_version": data["metadata"]["schema_version"], "counts": data["metadata"]["counts"], "files": {p.name: {"bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}}
        manifest_file = tmp / "manifest.json"
        manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n", "utf8")
        files.append(manifest_file)
        if args.check:
            stale = [p.name for p in files if not (OUT / p.name).is_file() or (OUT / p.name).read_bytes() != p.read_bytes()]
            if stale:
                raise SystemExit("DATABASE_CHECK FAIL stale: " + ", ".join(stale) + "; run python tools/build_database.py")
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            for p in files:
                (OUT / p.name).write_bytes(p.read_bytes())
        print("DATABASE_CHECK PASS" if args.check else "DATABASE_BUILD PASS", dumps(data["metadata"]["counts"]))


if __name__ == "__main__":
    main()
