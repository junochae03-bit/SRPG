extends RefCounted
## Read-only presentation adapter. Gameplay clocks and hit areas remain authoritative.
const CostumeArt = preload("res://scripts/costume_art_v04.gd")
const CATALOG_PATH = "res://assets/monster_motions_v06/catalog.json"
const MOTION_DURATION = 0.35
const IMPACT_REMAINING_FRACTION = 0.54
static var _catalog: Dictionary = {}
static var _loaded: bool = false
static var _frames: Dictionary = {}

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(CATALOG_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
			if parsed is Dictionary:
				_catalog = parsed
	return _catalog

static func species_id(enemy: Dictionary) -> String:
	var catalog = data()
	var kind = str(enemy.get("kind", ""))
	if not kind in catalog.get("base_ids", []): return ""
	var floor_number = int(enemy.get("floor", 0))
	if floor_number <= 0: return kind
	var chapters: Array = catalog.get("chapters", [])
	if chapters.is_empty(): return ""
	var theme = str(chapters[clampi(int((floor_number - 1) / 10), 0, chapters.size() - 1)])
	if bool(enemy.get("raid", false)):
		return str(catalog.get("raid_bosses", {}).get(theme, kind))
	return str(catalog.get("variants", {}).get(theme, {}).get(kind, kind))

static func pose_index(enemy: Dictionary) -> int:
	if float(enemy.get("hp", 1)) <= 0 or float(enemy.get("stun_time", 0)) > 0: return 0
	if enemy.get("stagger", {}).get("state", "") in ["check", "down"]: return 0
	# No healing pose exists in this pack; retain the existing support cast VFX.
	if float(enemy.get("support_cast", 0)) > 0: return 0
	if float(enemy.get("windup", 0)) > 0: return 1
	if enemy.get("attack_motion_kind", "attack") == "support": return 0
	var remaining = float(enemy.get("attack_motion", 0))
	if not is_finite(remaining) or remaining <= 0: return 0
	var duration = float(enemy.get("attack_motion_duration", MOTION_DURATION))
	if not is_finite(duration) or duration <= 0: duration = MOTION_DURATION
	return 2 if remaining / duration > IMPACT_REMAINING_FRACTION else 3

static func size_policy(enemy: Dictionary, identity: String = "") -> Dictionary:
	if identity.is_empty(): identity = species_id(enemy)
	var catalog = data()
	if not catalog.get("species", {}).has(identity): return {}
	var result: Dictionary = catalog.species[identity].get("size_policy", {}).duplicate(true)
	var floor_number = int(enemy.get("floor", 0))
	# Runtime enemies have no raid_id; the authored raid ID is their exact floor.
	if bool(enemy.get("raid", false)):
		var raid_id = "raid:%03d" % floor_number
		var override: Dictionary = catalog.get("raid_size_overrides", {}).get(raid_id, {})
		if override.get("base_monster_id", "") == str(enemy.get("kind", "")):
			result = override.duplicate(true)
	result["measurement"] = catalog.get("size_policy", {}).get("measurement", "")
	result["applied_by_reader"] = false
	return result

static func facing(enemy: Dictionary) -> float:
	# Art faces screen-left. Flip around the returned foot, never inside the atlas.
	# Simulation updates visual_direction only after actual movement, preserving
	# the last direction when stopped. Never face a stale spawn/attack position.
	var movement = enemy.get("visual_direction", Vector2.LEFT)
	var direction: Vector2 = movement if movement is Vector2 else Vector2.LEFT
	var controlled = float(enemy.get("hp", 1)) <= 0 or float(enemy.get("stun_time", 0)) > 0
	controlled = controlled or enemy.get("stagger", {}).get("state", "") in ["check", "down"]
	var attacking = float(enemy.get("windup", 0)) > 0 or (enemy.get("attack_motion_kind", "attack") != "support" and float(enemy.get("attack_motion", 0)) > 0)
	if attacking and not controlled and float(enemy.get("support_cast", 0)) <= 0:
		var position = enemy.get("pos", Vector2.ZERO)
		var target = enemy.get("attack_pos", position)
		if position is Vector2 and target is Vector2:
			var delta: Vector2 = target - position
			if absf(delta.x - delta.y) > 0.001: direction = delta
	var screen_x = direction.x - direction.y
	if is_finite(screen_x) and absf(screen_x) > 0.001:
		return -1.0 if screen_x > 0 else 1.0
	return 1.0

static func frame(enemy: Dictionary, _time: float = 0.0) -> Dictionary:
	# A wall clock must not cycle attack poses for walking/idle enemies.
	if bool(enemy.get("training", false)) or float(enemy.get("hp", 1)) <= 0: return {}
	var identity = species_id(enemy)
	var entry: Dictionary = data().get("species", {}).get(identity, {})
	if entry.is_empty(): return {}
	var index = pose_index(enemy)
	var poses: Array = entry.get("frames", [])
	if poses.size() != 4: return {}
	var pose: Dictionary = poses[index]
	var rect: Array = pose.get("rect", [])
	var foot: Array = pose.get("foot", [])
	var height = float(entry.get("body_height", 0))
	if rect.size() != 4 or foot.size() != 2 or not is_finite(height) or height <= 0: return {}
	for number in rect + foot:
		if not (number is int or number is float) or not is_finite(float(number)): return {}
	var region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	if region.size.x <= 0 or region.size.y <= 0: return {}
	var sheet_path = str(entry.get("sheet", ""))
	var cache_key = identity + ":" + str(index)
	if not _frames.has(cache_key):
		var sheet = CostumeArt._sheet_texture(sheet_path, "magenta_narrow")
		if sheet == null: return {}
		# Shared cache adds one transparent right/bottom pixel, not an origin offset.
		if not Rect2(Vector2.ZERO, sheet.get_size() - Vector2.ONE).encloses(region): return {}
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		atlas.filter_clip = true
		_frames[cache_key] = atlas
	return {
		"texture": _frames[cache_key], "foot": Vector2(float(foot[0]), float(foot[1])),
		"height": height, "animated": true, "index": index, "phase": str(pose.phase),
		"species": identity, "art_id": identity + "_" + str(pose.phase),
		"name": str(entry.get("name_ko", identity)), "source_facing": -1.0,
		"facing": facing(enemy), "sheet": sheet_path, "frame_source_path": sheet_path,
		"size_policy": size_policy(enemy, identity), "hovering": bool(entry.get("hovering", false)),
	}
