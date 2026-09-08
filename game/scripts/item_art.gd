extends RefCounted
static var cache:Dictionary={}
static func texture(key:String)->Texture2D:
	if cache.is_empty():
		var atlas:Texture2D=load("res://assets/sprites/items-v04.png")
		var regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/item_regions.json"))
		for name in regions:
			var r=regions[name];var result=AtlasTexture.new();result.atlas=atlas
			result.region=Rect2(r[0],r[1],r[2],r[3]);result.filter_clip=true;cache[name]=result
	return cache.get(key,cache.satchel)
