extends RefCounted
## Original costume sheets stay unchanged. Chroma removal happens once per sheet
## in memory, so callers can draw with an ordinary CanvasItem material.

const CATALOG_PATH = "res://assets/costume_v04/catalog.json"
const ID_FIELDS = ["costume_id", "costume", "skin_id", "custom_skin"]
static var _catalog_data: Dictionary = {}
static var _catalog_loaded = false
static var _sheet_textures: Dictionary = {}
static var _frame_textures: Dictionary = {}
static var _portraits: Dictionary = {}
static var _failed_sheets: Dictionary = {}

## The shared catalog is read-only to callers. No image is loaded here.
static func catalog() -> Dictionary:
	if not _catalog_loaded:
		_catalog_loaded = true
		if FileAccess.file_exists(CATALOG_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
			if parsed is Dictionary:
				_catalog_data = parsed
	return _catalog_data

static func ids() -> Array:
	var result = catalog().keys()
	result.sort()
	return result

static func recognizes(id: String) -> bool:
	return catalog().has(id) and catalog()[id] is Dictionary

static func id_for(p: Dictionary) -> String:
	for field in ID_FIELDS:
		var value = p.get(field, "")
		if value is String and recognizes(value):
			return value
	return ""

static func has_sprite(p: Dictionary) -> bool:
	return not id_for(p).is_empty()

## Explicit reset for a catalog reload or tests; never called by frame().
static func reset_cache(reload_catalog: bool = false) -> void:
	_sheet_textures.clear()
	_frame_textures.clear()
	_portraits.clear()
	_failed_sheets.clear()
	if reload_catalog:
		_catalog_data.clear()
		_catalog_loaded = false

static func index_for(p: Dictionary, time: float) -> int:
	if float(p.get("hurt_time", 0.0)) > 0.0:
		return 14
	if float(p.get("dodge_time", 0.0)) > 0.0:
		return 12 if float(p.get("dodge_time", 0.0)) > 0.13 else 13
	var charge = float(p.get("charge_time", -1.0))
	if charge >= 0.0:
		return 8 if charge < 0.45 else 9
	var remaining = float(p.get("motion_time", 0.0))
	if remaining > 0.0:
		var duration = maxf(0.01, float(p.get("motion_duration", remaining)))
		var progress = clampf(1.0 - remaining / duration, 0.0, 1.0)
		var step = mini(3, int(progress * 4.0))
		match str(p.get("motion", "")):
			"slam", "shoot_high", "cast_high":
				return 8 + step
			"dash", "leap", "blink":
				return 12 if step < 2 else 13
			_:
				return 4 + step
	var direction = p.get("dir", Vector2.ZERO)
	if direction is Vector2 and direction.length() > 0.1:
		var clock = time if is_finite(time) else 0.0
		return int(fposmod(clock * (12.0 if p.get("sprint", false) else 8.0), 4.0))
	return 15

static func _action_for(index: int) -> String:
	if index < 4: return "move"
	if index < 8: return "normal"
	if index < 12: return "strong"
	if index < 14: return "dodge"
	return "hurt" if index == 14 else "idle"

static func _sheet_key(path: String, key: String) -> String:
	return path + "|" + key

static func _source_image(path: String) -> Image:
	# Raw PNG bytes preserve authored RGB values when the source is present.
	if path.get_extension().to_lower() == "png" and FileAccess.file_exists(path):
		var bytes = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var raw = Image.new()
			if raw.load_png_from_buffer(bytes) == OK:
				return raw
	# Exported projects may contain only the imported resource/remap, not the PNG.
	if ResourceLoader.exists(path, "Texture2D"):
		var imported = ResourceLoader.load(path, "Texture2D") as Texture2D
		if imported != null:
			var source = imported.get_image()
			if source != null and not source.is_empty():
				if source.is_compressed() and source.decompress() != OK:
					return null
				return source
	return null

static func _keyed_image(source: Image, key: String) -> Image:
	if source == null or source.is_empty() or key not in ["blue", "magenta"]:
		return null
	var converted = source.duplicate() as Image
	if converted.is_compressed() and converted.decompress() != OK:
		return null
	converted.clear_mipmaps()
	converted.convert(Image.FORMAT_RGBA8)
	var data = converted.get_data()
	for offset in range(0, data.size(), 4):
		var red = int(data[offset])
		var green = int(data[offset + 1])
		var blue = int(data[offset + 2])
		# Exact byte equivalents of the documented strict normalized thresholds.
		var is_key = red <= 63 and green <= 63 and blue >= 166 if key == "blue" else red >= 166 and blue >= 166 and green <= 89
		if is_key:
			data[offset + 3] = 0
	return Image.create_from_data(converted.get_width(), converted.get_height(), false, Image.FORMAT_RGBA8, data)

static func _sheet_texture(path: String, key: String) -> ImageTexture:
	var cache_key = _sheet_key(path, key)
	if _sheet_textures.has(cache_key):
		return _sheet_textures[cache_key]
	if _failed_sheets.has(cache_key):
		return null
	var keyed = _keyed_image(_source_image(path), key)
	if keyed == null:
		_failed_sheets[cache_key] = true
		push_warning("Unable to load costume sheet: " + path)
		return null
	var texture = ImageTexture.create_from_image(_padded_image(keyed))
	_sheet_textures[cache_key] = texture
	return texture

static func _padded_image(source: Image) -> Image:
	# The legacy shared CanvasItem shader keys magenta by known texture sizes.
	# A transparent right/bottom pixel moves these RGBA sheets out of that branch
	# without moving any source pixel, atlas rectangle or foot coordinate.
	var padded = Image.create(source.get_width()+1, source.get_height()+1, false, Image.FORMAT_RGBA8)
	padded.fill(Color.TRANSPARENT)
	padded.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i.ZERO)
	return padded

static func _frame_at(id: String, index: int) -> Dictionary:
	if not recognizes(id):
		return {}
	var entry: Dictionary = catalog()[id]
	var frames = entry.get("frames", [])
	if not frames is Array or index < 0 or index >= frames.size() or not frames[index] is Dictionary:
		return {}
	var data: Dictionary = frames[index]
	var rect = data.get("rect", [])
	var foot = data.get("foot", [])
	if int(data.get("index", index)) != index or not rect is Array or rect.size() != 4 or not foot is Array or foot.size() != 2:
		return {}
	var height = float(data.get("body_height", entry.get("body_height", 0.0)))
	if not is_finite(height) or height <= 0.0:
		return {}
	var position = Vector2(float(foot[0]), float(foot[1]))
	var region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	if not position.is_finite() or not region.position.is_finite() or not region.size.is_finite() or region.size.x <= 0 or region.size.y <= 0:
		return {}
	var path = str(data.get("sheet", entry.get("sheet", "")))
	var key = str(data.get("chroma_key", entry.get("chroma_key", "")))
	var cache_key = id + ":" + str(index)
	if not _frame_textures.has(cache_key):
		var sheet = _sheet_texture(path, key)
		if sheet == null or not Rect2(Vector2.ZERO, sheet.get_size()-Vector2.ONE).encloses(region):
			return {}
		var texture = AtlasTexture.new()
		texture.atlas = sheet
		texture.region = region
		texture.filter_clip = true
		_frame_textures[cache_key] = texture
	return {"texture": _frame_textures[cache_key], "foot": position, "height": height,
		"animated": true, "index": index, "costume_id": id, "action": _action_for(index),
		"sheet": path, "frame_source_path": path}

## GatArt-compatible return contract. Unknown IDs return an empty dictionary.
static func frame(p: Dictionary, time: float) -> Dictionary:
	return _frame_at(id_for(p), index_for(p, time))

static func portrait(p: Dictionary) -> AtlasTexture:
	var id = id_for(p)
	if id.is_empty(): return null
	if _portraits.has(id): return _portraits[id]
	var idle = _frame_at(id, 15)
	if idle.is_empty(): return null
	var base = idle.texture as AtlasTexture
	var region = base.region
	var side = minf(float(idle.height) * 0.68, minf(region.size.x, region.size.y))
	var x = clampf(idle.foot.x - side * 0.5, 0.0, region.size.x - side)
	var y = clampf(idle.foot.y - idle.height, 0.0, region.size.y - side)
	var texture = AtlasTexture.new()
	texture.atlas = base.atlas
	texture.region = Rect2(region.position + Vector2(x, y), Vector2(side, side))
	texture.filter_clip = true
	_portraits[id] = texture
	return texture
