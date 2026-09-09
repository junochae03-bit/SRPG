extends RefCounted
static var catalog:Dictionary={}
static var cache:Dictionary={}
static func initialize():
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/biomes-v04/catalog.json"))
static func theme(zone:String,floor_number:int)->String:
	initialize()
	if floor_number>0:return catalog.chapters[clampi(int((floor_number-1)/10),0,9)]
	return zone if catalog.themes.has(zone) else "forest"
static func ids(zone:String,floor_number:int)->Array:
	initialize();return catalog.themes[theme(zone,floor_number)]
static func frame(id:String)->Dictionary:
	initialize();var entry=catalog.objects[id]
	if not cache.has(id):
		var texture=AtlasTexture.new();var r=entry.rect
		texture.atlas=load(entry.sheet);texture.region=Rect2(r[0],r[1],r[2],r[3]);texture.filter_clip=true
		cache[id]=texture
	return {"texture":cache[id],"foot":Vector2(entry.foot[0],entry.foot[1]),"height":entry.rect[3],"id":id}
static func height(id:String)->float:
	if id.contains("tree") or id.contains("fir") or id.contains("birch") or id.contains("cypress"):return 225.
	if id.contains("arch") or id.contains("gate") or id.contains("column") or id.contains("tower") or id.contains("pylon"):return 172.
	if id.contains("shrub") or id.contains("rubble") or id.contains("scrap") or id.contains("fragments"):return 72.
	if id.contains("boulder") or id.contains("log") or id.contains("cattail") or id.contains("boardwalk"):return 94.
	return 125.
