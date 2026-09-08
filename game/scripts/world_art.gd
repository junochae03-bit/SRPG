extends RefCounted
static var catalog:Dictionary={}
static var cache={}
static func initialize():
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/catalog.json"))
static func frame(kind:String,index:int)->Dictionary:
	initialize();var entry=catalog[kind];var data=entry.frames[index];var key=kind+str(index)
	if not cache.has(key):
		var r=data.rect;var tex=AtlasTexture.new();tex.atlas=load(entry.sheet);tex.region=Rect2(r[0],r[1],r[2],r[3]);tex.filter_clip=true;cache[key]=tex
	return {"texture":cache[key],"foot":Vector2(data.foot[0],data.foot[1]),"height":data.rect[3],"track":data.get("track",[])}
