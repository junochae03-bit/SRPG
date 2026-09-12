extends RefCounted
## Nonrectangular atlas slicing. Original texture pixels and world anchors stay
## intact; MeshTexture samples only this frame's reviewed source regions.
const PATH = "res://data/sprite_frame_regions.json"
static var entries: Dictionary = {}
static var loaded = false
static var cache: Dictionary = {}

static func initialize():
	if loaded: return
	loaded = true
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: entries = parsed.get("entries", {})

static func apply(raw: Dictionary, id: String) -> Dictionary:
	initialize()
	var spec: Dictionary = entries.get(id, {}).get(str(raw.index), {})
	if spec.is_empty(): return raw
	var key = id + ":" + str(raw.index)
	if not cache.has(key):
		var source = raw.texture as AtlasTexture
		if source == null: return raw
		cache[key] = build(source.atlas, spec)
	var result = raw.duplicate()
	result.texture = cache[key]
	result.foot = Vector2(spec.foot[0], spec.foot[1])
	result.region_corrected = true
	if spec.has("use_frame"): result.source_frame = int(spec.use_frame)
	return result

static func build(sheet: Texture2D, spec: Dictionary) -> Texture2D:
	var r = spec.rect
	if not spec.has("strips"):
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(r[0], r[1], r[2], r[3])
		atlas.filter_clip = true
		return atlas
	var origin = Vector2(r[0], r[1])
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	for strip in spec.strips:
		var rect = Rect2(strip[0], strip[1], strip[2], strip[3])
		var start = points.size()
		for corner in [rect.position, rect.position+Vector2(rect.size.x,0), rect.end, rect.position+Vector2(0,rect.size.y)]:
			points.append(corner-origin)
			uvs.append(corner/sheet.get_size())
		indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var texture = MeshTexture.new()
	texture.base_texture = sheet
	texture.image_size = Vector2(r[2], r[3])
	texture.mesh = mesh
	texture.set_meta("frame_region_spec", spec)
	return texture

static func bounds(texture: Texture2D) -> Rect2:
	# Geometry already bounds the visible silhouette; MeshTexture has no CPU image.
	return Rect2(Vector2.ZERO, texture.get_size())

static func crop(texture: MeshTexture, region: Rect2) -> Texture2D:
	var spec: Dictionary = texture.get_meta("frame_region_spec")
	var origin = Vector2(spec.rect[0], spec.rect[1])
	var absolute = Rect2(origin+region.position,region.size)
	var strips = []
	for values in spec.strips:
		var clipped = Rect2(values[0],values[1],values[2],values[3]).intersection(absolute)
		if clipped.has_area(): strips.append([clipped.position.x,clipped.position.y,clipped.size.x,clipped.size.y])
	return build(texture.base_texture,{"rect":[absolute.position.x,absolute.position.y,absolute.size.x,absolute.size.y],"strips":strips})
