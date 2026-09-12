extends RefCounted
## Test-only inspection of original sheet coordinates, including mesh UVs.
static func sheet(texture: Texture2D) -> Texture2D:
	if texture is AtlasTexture: return sheet(texture.atlas)
	if texture is MeshTexture: return sheet(texture.base_texture)
	return texture

static func origin(texture: Texture2D) -> Vector2:
	if texture is AtlasTexture: return origin(texture.atlas)+texture.region.position
	if texture is MeshTexture:
		var r=texture.get_meta("frame_region_spec",{}).get("rect",[])
		if r.size()==4:return origin(texture.base_texture)+Vector2(r[0],r[1])
	return Vector2.ZERO

static func geometry_valid(texture: Texture2D) -> bool:
	if texture is AtlasTexture:
		return texture.atlas!=null and texture.region.has_area() and Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region)
	if not texture is MeshTexture or texture.base_texture==null or texture.mesh==null:return false
	if not texture.has_meta("frame_region_spec") or texture.mesh.get_surface_count()!=1:return false
	var arrays=texture.mesh.surface_get_arrays(0)
	var vertices=arrays[Mesh.ARRAY_VERTEX];var uvs=arrays[Mesh.ARRAY_TEX_UV];var indices=arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or vertices.size()!=uvs.size() or indices.is_empty():return false
	var at=origin(texture)-origin(texture.base_texture)
	var frame_bounds=Rect2(Vector2(-.01,-.01),texture.get_size()+Vector2(.02,.02))
	for i in range(vertices.size()):
		var point=Vector2(vertices[i].x,vertices[i].y)
		if not frame_bounds.has_point(point):return false
		# UV samples and local vertices must map to the same ORIGINAL pixel.
		if (point+at-uvs[i]*texture.base_texture.get_size()).length()>.01:return false
	for index in indices:
		if index<0 or index>=vertices.size():return false
	return true

static func same_anchor(frame: Dictionary, original: Dictionary) -> bool:
	return sheet(frame.texture)==sheet(original.texture) and (origin(frame.texture)+frame.foot).is_equal_approx(origin(original.texture)+original.foot)

static func hud_crop_matches(source: Texture2D, portrait: Texture2D, crop: Rect2) -> bool:
	return source!=null and portrait!=null and sheet(source)==sheet(portrait) and geometry_valid(source) and geometry_valid(portrait) and origin(portrait).is_equal_approx(origin(source)+crop.position) and portrait.get_size().is_equal_approx(crop.size) and Rect2(Vector2.ZERO,source.get_size()).encloses(crop)
