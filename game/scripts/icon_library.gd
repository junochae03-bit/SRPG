extends RefCounted
## Shared semantic artwork. Atlas source PNGs are preserved without image edits.
const CATALOG_PATH="res://assets/icons/semantic_catalog.json"
static var entries:Dictionary={}
static var cache:Dictionary={}
static var resolved_keys:Dictionary={}
static var unknown_requests:Dictionary={}
const ALIASES={
	"potion":"consumable","satchel":"bag","growth":"skills","return":"return_home",
	"damage":"physical_attack","magic":"magic_attack","speed":"agility",
	"stamina_regen":"stamina","health_regen":"regen","potion_power":"heal",
	"xp_bonus":"experience","gold_bonus":"gold","heavy_power":"charge",
	"attack_haste":"attack_speed","skill_haste":"cooldown","skill_radius":"area",
	"skill_power":"arcane","melee_range":"range","dodge":"dash",
	"break_armor":"armor_break","crit":"critical","crit_damage":"critical_damage",
	"attack":"physical_attack","stand":"card_hold","buff":"haste","effects":"sound",
	"costume":"chest","training":"physical_attack"
}
static func initialize():
	if not entries.is_empty():return
	var data=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	for sheet in data.sheets:
		for index in range(sheet.items.size()):
			var rect:Array=sheet.frames[index] if sheet.has("frames") else [index%6*256,int(index/6)*256,256,256]
			entries[sheet.items[index]]={"path":sheet.path,"rect":rect}
static func canonical(key:String)->String:return ALIASES.get(key,key)
static func has_key(key:String)->bool:
	initialize()
	return entries.has(canonical(key))
static func keys()->Array:
	initialize()
	return entries.keys()
static func texture(key:String)->Texture2D:
	initialize()
	key=canonical(key)
	if not entries.has(key):unknown_requests[key]=true;key="unknown"
	resolved_keys[key]=true
	if not cache.has(key):
		var entry=entries[key]
		var result=AtlasTexture.new()
		result.atlas=load(entry.path)
		var r=entry.rect
		result.region=Rect2(r[0],r[1],r[2],r[3])
		result.filter_clip=true
		cache[key]=result
	return cache[key]
static func audit()->Dictionary:return {"resolved_keys":resolved_keys.keys(),"unknown_requests":unknown_requests.keys()}
static func attach(button:Button,key:String,icon_size:int=24):
	button.material=preload("res://scripts/gat_art.gd").material()
	if button.has_meta("rpg_frame") and button.size.x>=90:
		# Keep the icon inside the carved corner instead of over the ornament.
		for state in ["normal","hover","pressed","disabled","focus"]:
			var inset=button.get_theme_stylebox(state).duplicate()
			inset.content_margin_left=maxf(inset.content_margin_left,16)
			inset.content_margin_right=maxf(inset.content_margin_right,12)
			button.add_theme_stylebox_override(state,inset)
	button.icon=texture(key)
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",icon_size)
	button.add_theme_constant_override("h_separation",6)
	button.set_meta("semantic_icon",canonical(key))
static func picture(parent:Node,key:String,at:Vector2,dimensions:Vector2)->TextureRect:
	var result=preload("res://scripts/ui_art.gd").picture(parent,texture(key),at,dimensions)
	result.material=preload("res://scripts/gat_art.gd").material()
	result.set_meta("semantic_icon",canonical(key))
	return result
static func draw(canvas:CanvasItem,key:String,rect:Rect2,tint:Color=Color.WHITE):
	canvas.material=preload("res://scripts/gat_art.gd").material()
	canvas.draw_texture_rect(texture(key),rect,false,tint)
