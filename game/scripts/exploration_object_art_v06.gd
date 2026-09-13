extends RefCounted
## Presentation only. Pass the local viewer's authoritative exploration snapshot.
const EnvironmentArt = preload("res://scripts/environment_art.gd")
const CostumeArt = preload("res://scripts/costume_art_v04.gd")
const CATALOG_PATH = "res://assets/exploration_objects_v06/catalog.json"
static var _catalog: Dictionary = {}
static var _loaded: bool = false
static var _textures: Dictionary = {}

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(CATALOG_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
			if parsed is Dictionary: _catalog = parsed
	return _catalog

static func stable_hash(value: String) -> int:
	var result: int = 5381
	for byte_value in value.to_utf8_buffer():
		result = ((result * 33) ^ int(byte_value)) & 0x7fffffff
	return result

static func selection(site: Dictionary, zone: String, floor_number: int) -> Dictionary:
	# Raw map sites lack personal claim state and must not be rendered as snapshots.
	if floor_number <= 0 or not site.get("claimed") is bool: return {}
	if str(site.get("generation", "")).is_empty() or str(site.get("id", "")).is_empty(): return {}
	var kind = str(site.get("kind", ""))
	var event = str(site.get("event", ""))
	var category = ""
	if kind == "gather" and event.is_empty():
		category = str(site.get("material", ""))
		if category not in ["seed", "ore"]: return {}
	elif kind == "cache":
		if event == "herbalist": category = "herbalist"
		elif event in ["", "sealed_supplies"]: category = "cache"
		else: return {}
	else:
		return {}
	var biome = EnvironmentArt.theme(zone, floor_number)
	var pools: Dictionary = data().get("pools", {}).get(category, {})
	var pool: Array = pools.get(biome, pools.get("*", []))
	if pool.is_empty(): return {}
	var key = "%s|%s|%s|%s" % [site.generation, site.id, category, biome]
	var identity = str(pool[stable_hash(key) % pool.size()])
	var state = ("empty" if site.claimed else "closed") if category == "cache" else ("depleted" if site.claimed else "available")
	return {"id": identity, "state": state, "biome": biome, "category": category}

static func frame(site: Dictionary, zone: String, floor_number: int) -> Dictionary:
	var selected = selection(site, zone, floor_number)
	if selected.is_empty(): return {}
	var entry: Dictionary = data().get("objects", {}).get(selected.id, {})
	var pose: Dictionary = entry.get("frames", {}).get(selected.state, {})
	if pose.is_empty(): return {}
	var rect: Array = pose.get("rect", [])
	var foot: Array = pose.get("foot", [])
	var height = float(entry.get("body_height", 0))
	if rect.size() != 4 or foot.size() != 2 or not is_finite(height) or height <= 0: return {}
	for number in rect + foot:
		if not (number is int or number is float) or not is_finite(float(number)): return {}
	var region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	if region.size.x <= 0 or region.size.y <= 0: return {}
	var sheet_path = str(entry.get("sheet", ""))
	var key = str(selected.id) + ":" + str(selected.state)
	if not _textures.has(key):
		var sheet = CostumeArt._sheet_texture(sheet_path, "magenta_narrow")
		if sheet == null: return {}
		if not Rect2(Vector2.ZERO, sheet.get_size() - Vector2.ONE).encloses(region): return {}
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		atlas.filter_clip = true
		_textures[key] = atlas
	return {
		"texture": _textures[key], "foot": Vector2(float(foot[0]), float(foot[1])),
		"height": height, "id": str(selected.id), "state": str(selected.state),
		"art_id": str(selected.id) + "_" + str(selected.state), "biome": str(selected.biome),
		"sheet": sheet_path, "frame_source_path": sheet_path,
		"suggested_display_height": float(entry.get("suggested_display_height", 100)),
		"animated": false,
	}
