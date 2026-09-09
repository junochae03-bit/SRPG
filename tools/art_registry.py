"""Portable art registry enrichment and validation. Python standard library only.

Godot supplies actual catalog/consumer mappings. This module never scans an
extraction/source-art directory, creates artwork, or reads a game save.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import struct

TABLES = ["art_sources", "art_files", "art_assets", "art_uses"]
OWNER_TABLES = {"equipment": "equipment_id", "classes": "class_id", "skills": "skill_id", "constellations": "constellation_id", "monsters": "monster_id", "raids": "raid_id", "appearances": "appearance_id", "floors": "floor_id", "drops": "drop_id"}
CATEGORIES = {"equipment", "icon", "vfx", "environment", "monster", "character", "floor_tile", "ui"}


def digest(blob):
    return hashlib.sha256(blob).hexdigest()


def stable(prefix, text):
    return prefix + digest(text.encode("utf8"))[:24]


def local(root, reference):
    path = root / ("game/" + reference[6:] if reference.startswith("res://") else reference)
    path = path.resolve()
    assert path.is_relative_to(root.resolve()), f"Art reference escapes repository: {reference}"
    assert path.is_file(), f"Missing registered art source: {reference}"
    return path


def enrich(data, root):
    files, sources, documents = {}, {}, {}
    for asset in data["art_assets"]:
        path = local(root, asset["path"])
        provenance = asset["provenance"]
        if provenance not in documents:
            source_path = local(root, provenance)
            blob = source_path.read_bytes()
            documents[provenance] = json.loads(blob.decode("utf-8-sig")) if source_path.suffix == ".json" else {}
            sid = stable("source:", provenance)
            sources[provenance] = {"id": sid, "path": source_path.relative_to(root).as_posix(), "sha256": digest(blob), "kind": "catalog_provenance" if provenance.startswith("game/") else "project_provenance"}
        sid = sources[provenance]["id"]
        if asset["path"] not in files:
            blob = path.read_bytes()
            png = path.suffix.lower() == ".png"
            if png:
                assert blob[:8] == b"\x89PNG\r\n\x1a\n" and blob[12:16] == b"IHDR", f"Invalid PNG {path}"
                width, height = struct.unpack(">II", blob[16:24])
            else:
                assert path.suffix in (".gd", ".gdshader"), f"Unsupported art representation: {path}"
                width = height = 0
            record = {"id": stable("file:", asset["path"]), "path": asset["path"], "sha256": digest(blob), "bytes": len(blob), "width": width, "height": height, "representation": "raster" if png else "procedural", "source_id": sid, "origin": {}}
            doc = documents[provenance]
            # Preserve per-image original-path/manifest evidence where supplied.
            if provenance == "docs/ENVIRONMENT_V04_PROVENANCE.json":
                evidence = next(r for r in doc["files"] if r["runtime"] == asset["path"])
                assert evidence["sha256"] == record["sha256"], f"Environment provenance mismatch: {path}"
                record["origin"] = {k: v for k, v in evidence.items() if k not in ("objects", "runtime", "bytes")}
            elif provenance == "docs/costume_v04/PROVENANCE.json":
                evidence = next(r for r in doc["images"] if r["file"] == path.name)
                assert evidence["sha256"] == record["sha256"], f"Costume provenance mismatch: {path}"
                record["origin"] = {"tool": doc.get("generated_with", ""), "source_sheet": path.name, "original_pixels_preserved": True}
            elif asset["category"] == "floor_tile":
                assert doc["sha256"] == record["sha256"], "Ground atlas provenance mismatch"
                record["origin"] = {k: doc[k] for k in ("source", "provenance", "sampling")}
            elif asset["category"] == "equipment" and "equipment_key" in asset["metadata"]:
                catalog = json.loads(local(root, asset["catalog"]).read_text("utf8"))
                sheet = next(s for s in catalog["sheets"].values() if s["sheet"] == asset["path"])
                assert sheet["source_sha256"] == record["sha256"], f"Equipment provenance mismatch: {path}"
                record["origin"] = {"commit": "be30d7b0a75e0b7783c52c225bb2cab80df85a9d", "tool": doc.get("tool", ""), "source_sha256": sheet["source_sha256"]}
            else:
                record["origin"] = {"scope": "Current project source; consult linked provenance document", "tool": doc.get("tool", "")}
            files[asset["path"]] = record
        asset["file_id"] = files[asset["path"]]["id"]
        asset["source_id"] = sid
        local(root, asset["catalog"])
    data["art_sources"] = list(sources.values())
    data["art_files"] = list(files.values())
    data["metadata"]["art_registry"] = {
        "version": 1,
        "scope": "Reachable authored regions, consumer/catalog mappings and procedural effects, not per-session draw telemetry.",
        "hashes": "SHA256 of preserved runtime source PNG/script bytes and repository provenance documents. In-memory RGBA caches are not extra files.",
        "availability": "Applied regions have runtime_mapping consumers. Finished icon/costume regions without current gameplay use are available_catalog with catalog_available consumers only.",
        "excluded": "Unfinished theme equipment, source extraction archives, unused wall/TileSet assets and procedurally replaced job FX rows.",
    }
    return data


def validate(data, root):
    indexed = {}
    for table in TABLES:
        indexed[table] = {r["id"]: r for r in data[table]}
        assert len(indexed[table]) == len(data[table]), f"Duplicate art registry ID: {table}"
    files, sources, assets = indexed["art_files"], indexed["art_sources"], indexed["art_assets"]
    owners = {table: {str(row["id"]) for row in rows if "id" in row} for table, rows in data.items() if isinstance(rows, list)}
    used = set()
    applied = set()
    checked_consumers = set()
    for use in data["art_uses"]:
        assert use["art_id"] in assets, "Dangling art-use reference"
        assert use["target_table"] in ("runtime", "catalog") or use["target_id"] in owners.get(use["target_table"], set()), f"Dangling game owner: {use}"
        assert use["usage_kind"] in ("runtime_mapping", "catalog_available")
        if use["usage_kind"] == "runtime_mapping":
            assert use["target_table"] != "catalog"
            applied.add(use["art_id"])
        else:
            assert use["target_table"] == "catalog" and use["target_id"] == assets[use["art_id"]]["catalog"]
        assert use["target_id"], "Missing consumer mapping"
        script = use["consumer"].split(":", 1)[0] if not use["consumer"].startswith("res://") else use["consumer"]
        if script not in checked_consumers:
            local(root, script)
            checked_consumers.add(script)
        used.add(use["art_id"])
    assert used == set(assets), f"Unused registered regions: {set(assets)-used}"
    for asset in assets.values():
        assert asset["status"] == ("applied" if asset["id"] in applied else "available_catalog"), "Art availability incorrectly claims runtime use"
        assert asset["category"] in CATEGORIES
        assert asset["file_id"] in files and asset["source_id"] in sources
        file = files[asset["file_id"]]
        assert file["path"] == asset["path"]
        rect = asset["rect"]
        if file["representation"] == "procedural":
            assert rect == [] and asset["category"] == "vfx"
        else:
            assert len(rect) == 4 and all(isinstance(n, (int, float)) and math.isfinite(n) for n in rect)
            x, y, w, h = rect
            assert x >= 0 and y >= 0 and w > 0 and h > 0 and x+w <= file["width"]+.001 and y+h <= file["height"]+.001, f"Atlas bounds: {asset['id']} {rect} vs {file['width']}x{file['height']}"
        assert len(file["sha256"]) == 64 and file["bytes"] > 0
        assert file["source_id"] in sources
    assert {a["file_id"] for a in assets.values()} == set(files), "Unused file record"
    equipment = {a["id"] for a in assets.values() if a["metadata"].get("equipment_key")}
    assert len(equipment) == 115 and len({a["path"] for a in assets.values() if a["id"] in equipment}) == 6
    equipped = {u["target_id"] for u in data["art_uses"] if u["target_table"] == "equipment" and u["art_id"] in equipment}
    assert equipped == owners["equipment"], "Equipment definitions missing live artwork"
    floors = {u["target_id"] for u in data["art_uses"] if u["target_table"] == "floors" and assets[u["art_id"]]["category"] == "floor_tile"}
    assert floors == owners["floors"], "Missing live floor material mapping"
    assert len([a for a in assets.values() if a["category"] == "floor_tile"]) == 6
    assert len([a for a in assets.values() if a["id"].startswith("art:environment:")]) == 108
    assert len([a for a in assets.values() if a["id"].startswith("art:monster:") and not a["id"].startswith("art:monster:legacy:")]) == 48
    for table in ("skills", "constellations"):
        covered = {u["target_id"] for u in data["art_uses"] if u["target_table"] == table and assets[u["art_id"]]["category"] == "icon"}
        assert covered == owners[table], f"Missing actual skill icon mapping: {table}"
    return indexed


SCHEMA = """
CREATE TABLE art_sources(id TEXT PRIMARY KEY,path TEXT NOT NULL UNIQUE,sha256 TEXT NOT NULL CHECK(length(sha256)=64),kind TEXT NOT NULL);
CREATE TABLE art_files(id TEXT PRIMARY KEY,path TEXT NOT NULL UNIQUE,sha256 TEXT NOT NULL CHECK(length(sha256)=64),bytes INTEGER NOT NULL CHECK(bytes>0),width INTEGER NOT NULL,height INTEGER NOT NULL,representation TEXT NOT NULL CHECK(representation IN ('raster','procedural')),source_id TEXT NOT NULL REFERENCES art_sources(id),origin_json TEXT NOT NULL);
CREATE TABLE art_assets(id TEXT PRIMARY KEY,category TEXT NOT NULL,name TEXT NOT NULL,file_id TEXT NOT NULL REFERENCES art_files(id),source_id TEXT NOT NULL REFERENCES art_sources(id),x REAL,y REAL,width REAL,height REAL,frame INTEGER NOT NULL,action TEXT NOT NULL,catalog_path TEXT NOT NULL,metadata_json TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('applied','available_catalog')));
CREATE TABLE art_uses(id TEXT PRIMARY KEY,art_id TEXT NOT NULL REFERENCES art_assets(id),target_table TEXT NOT NULL,target_id TEXT NOT NULL,consumer TEXT NOT NULL,mapping_json TEXT NOT NULL,usage_kind TEXT NOT NULL CHECK(usage_kind IN ('runtime_mapping','catalog_available')),__OWNER_FIELDS__,CHECK(__OWNER_CHECK__),CHECK((target_table='catalog')=(usage_kind='catalog_available')));
CREATE INDEX art_by_category ON art_assets(category,name);
CREATE INDEX art_by_file ON art_assets(file_id);
CREATE INDEX art_uses_by_owner ON art_uses(target_table,target_id);
CREATE INDEX art_uses_by_asset ON art_uses(art_id);
CREATE VIEW art_catalog AS SELECT a.*,f.path runtime_path,f.sha256 runtime_sha256,f.bytes,f.representation,s.path provenance_path,s.sha256 provenance_sha256,f.origin_json FROM art_assets a JOIN art_files f ON f.id=a.file_id JOIN art_sources s ON s.id=a.source_id;
CREATE VIEW art_usage AS SELECT a.category,a.name,a.id art_id,a.status,u.usage_kind,u.target_table,u.target_id,u.consumer,u.mapping_json,a.runtime_path,a.runtime_sha256,a.x,a.y,a.width,a.height,a.frame,a.action,a.provenance_path FROM art_catalog a JOIN art_uses u ON u.art_id=a.id;
"""
_owner_count = " + ".join(f"({field} IS NOT NULL)" for field in OWNER_TABLES.values())
_owner_conditions = [f"(target_table IN ('runtime','catalog') AND ({_owner_count})=0)"] + [f"(target_table='{table}' AND {field}=target_id AND ({_owner_count})=1)" for table, field in OWNER_TABLES.items()]
SCHEMA = SCHEMA.replace("__OWNER_FIELDS__", ",".join(f"{field} {'INTEGER' if table == 'floors' else 'TEXT'} REFERENCES {table}(id)" for table, field in OWNER_TABLES.items())).replace("__OWNER_CHECK__", " OR ".join(_owner_conditions))


def insert_sqlite(con, data):
    j = lambda value: json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    for r in data["art_sources"]:
        con.execute("INSERT INTO art_sources VALUES (?,?,?,?)", (r["id"], r["path"], r["sha256"], r["kind"]))
    for r in data["art_files"]:
        con.execute("INSERT INTO art_files VALUES (?,?,?,?,?,?,?,?,?)", (r["id"], r["path"], r["sha256"], r["bytes"], r["width"], r["height"], r["representation"], r["source_id"], j(r["origin"])))
    for r in data["art_assets"]:
        rect = r["rect"] or [None]*4
        con.execute("INSERT INTO art_assets VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", (r["id"], r["category"], r["name"], r["file_id"], r["source_id"], *rect, r["frame"], r["action"], r["catalog"], j(r["metadata"]), r["status"]))
    for r in data["art_uses"]:
        owner_fields = [r["target_id"] if r["target_table"] == table else None for table in OWNER_TABLES]
        con.execute("INSERT INTO art_uses VALUES ("+",".join("?" for _ in range(7+len(owner_fields)))+")", (r["id"], r["art_id"], r["target_table"], r["target_id"], r["consumer"], j(r["mapping"]), r["usage_kind"], *owner_fields))
