extends RefCounted
## Exact 29 approved combat IDs. Read-only presentation; main owns combat timing.
const CostumeArt = preload("res://scripts/costume_art_v04.gd")
const LegacyMotion = preload("res://scripts/monster_motion_art_v06.gd")
const CATALOG_PATH = "res://assets/monster_ecology_v071/catalog.json"
static var _catalog: Dictionary = {}
static var _loaded: bool = false
static var _frames: Dictionary = {}

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(CATALOG_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
			if parsed is Dictionary: _catalog = parsed
	return _catalog

static func recognizes(identity: String) -> bool:
	return data().get("species", {}).has(identity)

static func timing(identity: String) -> Dictionary:
	return data().get("species", {}).get(identity, {}).get("timing", {}).duplicate(true)

static func pose_index(enemy: Dictionary) -> int:
	var identity = str(enemy.get("kind", ""))
	if not recognizes(identity): return 0
	if float(enemy.get("hp", 1)) <= 0 or float(enemy.get("stun_time", 0)) > 0: return 0
	if enemy.get("stagger", {}).get("state", "") in ["check", "down"]: return 0
	if float(enemy.get("support_cast", 0)) > 0: return 0
	if float(enemy.get("windup", 0)) > 0: return 1
	if enemy.get("attack_motion_kind", "attack") == "support": return 0
	var remaining = float(enemy.get("attack_motion", 0))
	if not is_finite(remaining) or remaining <= 0: return 0
	var contract: Dictionary = data().species[identity].timing
	var duration = float(enemy.get("attack_motion_duration", contract.recovery_seconds))
	if not is_finite(duration) or duration <= 0: duration = float(contract.recovery_seconds)
	# Only an authoritative impact refresh can replay the hit pose for a followup.
	var impact_left = float(enemy.get("attack_impact_time", 0))
	if is_finite(impact_left) and impact_left > 0: return 2
	var elapsed = maxf(0.0, duration - remaining)
	return 2 if elapsed < minf(float(contract.impact_visual_seconds), duration) else 3

static func frame(enemy: Dictionary, _time: float = 0.0) -> Dictionary:
	if float(enemy.get("hp", 1)) <= 0 or bool(enemy.get("training", false)): return {}
	if bool(enemy.get("boss", false)) or bool(enemy.get("raid", false)): return {}
	var identity = str(enemy.get("kind", ""))
	var entry: Dictionary = data().get("species", {}).get(identity, {})
	if entry.is_empty(): return {}
	var index = pose_index(enemy)
	var poses: Array = entry.get("frames", [])
	if poses.size() != 4: return {}
	var pose: Dictionary = poses[index]
	var rect: Array = pose.get("rect", [])
	var foot: Array = pose.get("foot", [])
	var height = float(entry.get("body_height", 0))
	var body_pixels = float(entry.get("body_pixels", 0))
	if rect.size() != 4 or foot.size() != 2 or not is_finite(height) or height <= 0: return {}
	if not is_finite(body_pixels) or body_pixels <= 0: return {}
	for number in rect + foot:
		if not (number is int or number is float) or not is_finite(float(number)): return {}
	var region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	if region.size.x <= 0 or region.size.y <= 0: return {}
	var sheet_path = str(entry.get("sheet", ""))
	var cache_key = identity + ":" + str(index)
	if not _frames.has(cache_key):
		var sheet = CostumeArt._sheet_texture(sheet_path, "magenta_narrow")
		if sheet == null: return {}
		if not Rect2(Vector2.ZERO, sheet.get_size() - Vector2.ONE).encloses(region): return {}
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		atlas.filter_clip = true
		_frames[cache_key] = atlas
	return {
		"texture": _frames[cache_key], "foot": Vector2(float(foot[0]), float(foot[1])),
		"height": height, "body_pixels": body_pixels, "display_height": body_pixels,
		"scale": body_pixels / height, "display_ratio": float(entry.display_ratio),
		"size_class": str(entry.size_class), "reference_character_height": 112.0,
		"animated": true, "index": index, "phase": str(pose.phase),
		"species": identity, "art_id": identity + "_" + str(pose.phase),
		"name": str(entry.name_ko), "source_facing": -1.0, "facing": LegacyMotion.facing(enemy),
		"sheet": sheet_path, "frame_source_path": sheet_path,
		"hovering": bool(entry.hovering), "timing": timing(identity),
		"pattern_id": str(entry.pattern.id),
	}
