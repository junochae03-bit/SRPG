extends RefCounted
static var catalog:Dictionary={}
static var cache={}
static var dungeon_catalog:Dictionary={}
static func initialize():
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/catalog.json"))
static func frame(kind:String,index:int)->Dictionary:
	initialize();var entry=catalog[kind];var data=entry.frames[index];var key=kind+str(index)
	if not cache.has(key):
		var r=data.rect;var tex=AtlasTexture.new();tex.atlas=load(entry.sheet);tex.region=Rect2(r[0],r[1],r[2],r[3]);tex.filter_clip=true;cache[key]=tex
	return {"texture":cache[key],"foot":Vector2(data.foot[0],data.foot[1]),"height":data.rect[3],"track":data.get("track",[])}

static func dungeon_initialize():
	if dungeon_catalog.is_empty():dungeon_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/dungeon-v04/catalog.json"))
static func variant(kind:String,floor_number:int,raid:bool=false)->Dictionary:
	dungeon_initialize()
	if floor_number<=0:return {}
	var theme=preload("res://scripts/environment_art.gd").theme("",floor_number)
	if not dungeon_catalog.themes.has(theme):return {}
	var id=""
	if raid:
		id=dungeon_catalog.themes[theme].bosses[0]
	else:
		var species=dungeon_catalog.variants.get(theme,{}).get(kind,"")
		if species.is_empty():return {}
		id=species+"_idle"
	return dungeon_catalog.objects[id]
static func variant_frame(kind:String,floor_number:int,raid:bool=false,attacking:bool=false)->Dictionary:
	var idle=variant(kind,floor_number,raid)
	if idle.is_empty():return {}
	var id=idle.species+("_attack" if attacking else "_idle");var entry=dungeon_catalog.objects[id]
	if not cache.has(id):
		var r=entry.rect;var texture=AtlasTexture.new();texture.atlas=load(entry.sheet)
		texture.region=Rect2(r[0],r[1],r[2],r[3]);texture.filter_clip=true;cache[id]=texture
	return {"texture":cache[id],"foot":Vector2(entry.foot[0],entry.foot[1]),"height":idle.body_height,"art_id":id,"species":entry.species,"name":entry.name,"pose":entry.pose}

static func appearance_name(kind:String,floor_number:int,fallback:String)->String:
	var idle=variant(kind,floor_number)
	return str(idle.name).trim_suffix(" 대기") if not idle.is_empty() else fallback
