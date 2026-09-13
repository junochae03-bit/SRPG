extends RefCounted
## Small ground fragments. Atlas regions preserve the generated PNG and its alpha.
const CATALOG="res://assets/exploration_traces_v06/catalog.json"
static var data:Dictionary={}
static var textures:Dictionary={}
static func catalog()->Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return data
static func texture(key:String)->AtlasTexture:
	if not textures.has(key):
		var entry=catalog();var rect=entry.sprites[key].rect
		var atlas=AtlasTexture.new();atlas.atlas=load(entry.sprites[key].get("sheet",entry.sheet))
		atlas.region=Rect2(rect[0],rect[1],rect[2],rect[3]);atlas.filter_clip=true
		textures[key]=atlas
	return textures[key]
