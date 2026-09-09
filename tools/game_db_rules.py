"""World/service contract extension used by the single build_database entry point."""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TABLES = ["facilities", "item_definitions", "service_operations", "service_samples",
          "service_inputs", "service_outputs", "service_effects", "dungeon_layouts",
          "training_rules", "inventory_rules"]
SOURCES = {
    "town_operations": "game/scripts/town_operations.gd",
    "service_quote": "game/scripts/service_quote.gd",
    "town_services": "game/scripts/town_services.gd",
    "dungeon": "game/scripts/dungeon.gd",
    "training": "game/scripts/training_ground.gd",
    "inventory": "game/scripts/inventory_model.gd",
    "simulation": "game/scripts/simulation.gd",
    "wardrobe": "game/scripts/wardrobe.gd",
    "world": "game/scripts/world_catalog.gd",
}


def source_rule(root, source, symbol):
    """Preserve the authoritative function, not a manually copied formula."""
    path = SOURCES[source]
    blob = (root / path).read_bytes()
    text = blob.decode("utf-8-sig")
    match = re.search(r"^(?:static )?func " + re.escape(symbol) + r"\([^\n]*", text, re.M)
    if not match:
        raise ValueError(f"Missing DB rule {path}:{symbol}")
    end = re.search(r"^(?:static )?func |^const |^var |^static var ", text[match.end():], re.M)
    body = text[match.start():match.end() + end.start() if end else len(text)].rstrip()
    return {"source_path": path, "source_symbol": symbol,
            "source_sha256": hashlib.sha256(blob).hexdigest(), "source_code": body}


def enrich(data, root):
    for table in TABLES:
        if table not in data:
            raise ValueError(f"Live export is missing {table}; export the current game_database.gd")
    # Discover legacy operations from the dispatcher; first-route operations
    # already have evaluated samples and must not be duplicated.
    operations = {r["id"]: r for r in data["service_operations"]}
    dispatcher = source_rule(root, "town_services", "transact")
    for key in re.findall(r'"([a-z_]+:[a-z_]+)"', dispatcher["source_code"]):
        if key not in operations:
            facility, operation = key.split(":")
            operations[key] = {"id": key, "facility_id": facility, "operation": operation,
                               "route": "town_services", "evaluation": "source_rule"}
    data["service_operations"] = list(operations.values())
    data["service_effects"] = []
    for key, row in operations.items():
        route = row["route"]
        row["access_rule"] = dispatcher
        row["quote_rule"] = source_rule(root, "town_operations" if route == "town_operations" else "service_quote",
                                         "describe" if route == "town_operations" else "quote")
        quantities = sorted({s["quantity"] for s in data["service_samples"] if s["operation_id"] == key})
        row["sampled_quantities"] = quantities
        data["service_effects"].append({"id": key + ":state_transition", "operation_id": key,
                                       "rule": source_rule(root, route, "stage" if route == "town_operations" else "transact"),
                                       "dispatch_key": key, "representation": "authoritative_source_rule"})
    for row in data["facilities"]:
        row["access_rule"] = source_rule(root, "world", "nearest")
        if row["id"] == "costume":
            row["wardrobe_source"] = SOURCES["wardrobe"]
    for row in data["dungeon_layouts"]:
        row["rules"] = [source_rule(root, "dungeon", name) for name in
                        ("generate_floor", "transform_anchor", "carve_room", "carve_segment",
                         "build_encounters", "formation_positions", "find_encounter_position", "valid_encounter_position")]
    for row in data["training_rules"]:
        row["rules"] = [source_rule(root, "training", name) for name in
                        ("can_practice", "spawn", "summary", "record", "tick", "reset")]
        # Death dispatch determines reward/drop/quest bypass, not the ordinary
        # monster's drops. Preserve the actual dispatcher as part of this rule.
        sim_text = (root / SOURCES["simulation"]).read_text("utf-8-sig")
        guard = re.search(r'^\tif enemy.get\("training",false\):enemy.hp=enemy.max_hp;return$', sim_text, re.M)
        if not guard:
            raise ValueError("Training reward guard changed; review and update the DB contract")
        preceding = list(re.finditer(r'^func (\w+)\(', sim_text[:guard.start()], re.M))
        if not preceding:
            raise ValueError("Cannot locate training reward dispatcher")
        row["reward_rule"] = source_rule(root, "simulation", preceding[-1].group(1))
        row["reward_policy"] = "training_guard_returns_before_normal_death_rewards"
    for row in data["inventory_rules"]:
        row["rules"] = [source_rule(root, "inventory", name) for name in
                        ("all_items", "bag_items", "add_stack", "can_place")]
    data["metadata"]["schema_version"] = 4
    data["metadata"]["world_rules_note"] = "거래 입력·출력은 명시된 기준 상태에서 계산한 예시입니다. 기존 동적 작업은 실행 원본 규칙을 보존합니다. 플레이어 저장 파일은 읽지 않습니다."
    return data


def validate(data):
    indexes = {}
    for table in TABLES:
        rows = data[table]
        indexes[table] = {r["id"]: r for r in rows}
        assert len(rows) == len(indexes[table]), f"Duplicate ID: {table}"
        assert rows, f"Empty required table: {table}"
    for row in data["service_operations"]:
        assert row["facility_id"] in indexes["facilities"]
        assert row["id"] == row["facility_id"] + ":" + row["operation"]
    for row in data["service_samples"]:
        assert row["operation_id"] in indexes["service_operations"]
        assert type(row["quantity"]) is int and row["quantity"] > 0
        assert row["gold_cost"] >= 0 and row["gold_reward"] >= 0
        assert not (row["gold_cost"] and row["gold_reward"])
        assert row["storage_checked"] is False
    for table in ("service_inputs", "service_outputs"):
        for row in data[table]:
            assert row["item_id"] in indexes["item_definitions"]
            assert row["sample_id"] in indexes["service_samples"]
            assert indexes["service_samples"][row["sample_id"]]["operation_id"] == row["operation_id"]
            assert type(row["amount"]) is int and row["amount"] > 0
    for row in data["service_effects"]:
        assert row["operation_id"] in indexes["service_operations"]
        assert row["rule"]["source_code"]
    for row in data["inventory_rules"]:
        assert row["width"] > 0 and row["height"] > 0
        assert row["capacity"] == row["width"] * row["height"]
        assert row["max_potions"] > 0
        assert type(row["max_materials"]) is int and row["max_materials"] > 0
    orders = sorted(r["selection_order"] for r in data["dungeon_layouts"])
    assert orders == list(range(len(orders)))
    for row in data["dungeon_layouts"]:
        points = row["points"]
        assert len(points) > 1
        reached = {0}
        for a, b in row["links"]:
            assert 0 <= a < len(points) and 0 <= b < len(points) and a != b
        while True:
            previous = set(reached)
            for a, b in row["links"]:
                if a in reached or b in reached: reached.update((a, b))
            if previous == reached: break
        assert len(reached) == len(points), f"Disconnected layout {row['id']}"
    for row in data["training_rules"]:
        assert row["facility_id"] in indexes["facilities"]
        assert row["health"] > 0 and row["empty_summary"]["dps"] == 0
        assert len(row["area"]) == 4 and min(row["area"][2:]) > 0
        x, y, w, h = row["area"]
        px, py = row["position"]
        assert x <= px < x+w and y <= py < y+h


SCHEMA = """
PRAGMA user_version=4;
CREATE TABLE facilities(id TEXT PRIMARY KEY,name TEXT NOT NULL,definition_json TEXT NOT NULL);
CREATE TABLE item_definitions(id TEXT PRIMARY KEY,name TEXT NOT NULL);
CREATE TABLE service_operations(id TEXT PRIMARY KEY,facility_id TEXT NOT NULL REFERENCES facilities(id),operation TEXT NOT NULL,definition_json TEXT NOT NULL,UNIQUE(facility_id,operation));
CREATE TABLE service_samples(id TEXT PRIMARY KEY,operation_id TEXT NOT NULL REFERENCES service_operations(id),quantity INTEGER NOT NULL CHECK(quantity>0),gold_cost INTEGER NOT NULL CHECK(gold_cost>=0),gold_reward INTEGER NOT NULL CHECK(gold_reward>=0),definition_json TEXT NOT NULL,CHECK(gold_cost=0 OR gold_reward=0),UNIQUE(id,operation_id));
CREATE TABLE service_inputs(id TEXT PRIMARY KEY,operation_id TEXT NOT NULL REFERENCES service_operations(id),sample_id TEXT NOT NULL,item_id TEXT NOT NULL REFERENCES item_definitions(id),amount INTEGER NOT NULL CHECK(amount>0),FOREIGN KEY(sample_id,operation_id) REFERENCES service_samples(id,operation_id));
CREATE TABLE service_outputs(id TEXT PRIMARY KEY,operation_id TEXT NOT NULL REFERENCES service_operations(id),sample_id TEXT NOT NULL,item_id TEXT NOT NULL REFERENCES item_definitions(id),amount INTEGER NOT NULL CHECK(amount>0),FOREIGN KEY(sample_id,operation_id) REFERENCES service_samples(id,operation_id));
CREATE TABLE service_effects(id TEXT PRIMARY KEY,operation_id TEXT NOT NULL REFERENCES service_operations(id),definition_json TEXT NOT NULL);
CREATE TABLE dungeon_layouts(id TEXT PRIMARY KEY,selection_order INTEGER NOT NULL UNIQUE CHECK(selection_order>=0),definition_json TEXT NOT NULL);
CREATE TABLE training_rules(id TEXT PRIMARY KEY,facility_id TEXT NOT NULL REFERENCES facilities(id),definition_json TEXT NOT NULL);
CREATE TABLE inventory_rules(id TEXT PRIMARY KEY,width INTEGER NOT NULL CHECK(width>0),height INTEGER NOT NULL CHECK(height>0),capacity INTEGER NOT NULL CHECK(capacity=width*height),max_potions INTEGER NOT NULL CHECK(max_potions>0),max_materials INTEGER NOT NULL CHECK(max_materials>0 AND typeof(max_materials)='integer'),definition_json TEXT NOT NULL);
"""


def insert(con, data):
    def dump(value):
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    for r in data["facilities"]: con.execute("INSERT INTO facilities VALUES (?,?,?)", (r["id"], r["name"], dump(r)))
    for r in data["item_definitions"]: con.execute("INSERT INTO item_definitions VALUES (?,?)", (r["id"], r["name"]))
    for r in data["service_operations"]: con.execute("INSERT INTO service_operations VALUES (?,?,?,?)", (r["id"], r["facility_id"], r["operation"], dump(r)))
    for r in data["service_samples"]: con.execute("INSERT INTO service_samples VALUES (?,?,?,?,?,?)", (r["id"], r["operation_id"], r["quantity"], r["gold_cost"], r["gold_reward"], dump(r)))
    for table in ("service_inputs", "service_outputs"):
        for r in data[table]: con.execute(f"INSERT INTO {table} VALUES (?,?,?,?,?)", (r["id"], r["operation_id"], r["sample_id"], r["item_id"], r["amount"]))
    for r in data["service_effects"]: con.execute("INSERT INTO service_effects VALUES (?,?,?)", (r["id"], r["operation_id"], dump(r)))
    for r in data["dungeon_layouts"]: con.execute("INSERT INTO dungeon_layouts VALUES (?,?,?)", (r["id"], r["selection_order"], dump(r)))
    for r in data["training_rules"]: con.execute("INSERT INTO training_rules VALUES (?,?,?)", (r["id"], r["facility_id"], dump(r)))
    for r in data["inventory_rules"]: con.execute("INSERT INTO inventory_rules VALUES (?,?,?,?,?,?,?)", (r["id"], r["width"], r["height"], r["capacity"], r["max_potions"], r["max_materials"], dump(r)))
