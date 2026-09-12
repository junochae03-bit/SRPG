extends RefCounted
const Content=preload("res://scripts/content.gd")
static var catalog:Dictionary={}
static var textures:Dictionary={}
static var shared_material:ShaderMaterial
static func initialize():
	if not catalog.is_empty():return
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/gat/catalog.json"))
static func material()->ShaderMaterial:
	if shared_material==null:
		shared_material=ShaderMaterial.new();shared_material.shader=preload("res://shaders/gat_chroma.gdshader")
	return shared_material
static func avatar(p:Dictionary)->String:
	if p.get("costume","") in Content.GAT_COSTUMES:return p.costume
	var selected=p.get("avatar","auto")
	return {"warrior":"gat_role_tank_2","ranger":"gat_role_single_1","mage":"gat_role_aoe_1"} .get(Content.base_class(p.get("class_id","warrior")),"gat_role_tank_2") if selected=="auto" else selected
static func texture(key:String,index:int)->AtlasTexture:
	initialize();var cache_key=key+str(index)
	if not textures.has(cache_key):
		var entry=catalog[key];var r=entry.frames[index].rect
		var atlas=AtlasTexture.new();atlas.atlas=load(entry.sheet);atlas.region=Rect2(r[0],r[1],r[2],r[3]);atlas.filter_clip=true;textures[cache_key]=atlas
	return textures[cache_key]
static func frame(p:Dictionary,time:float)->Dictionary:
	var raw=_frame(p,time)
	return preload("res://scripts/character_presentation.gd").apply(raw,presentation_id(p))
static func presentation_id(p:Dictionary)->String:
	var costume=preload("res://scripts/costume_art_v04.gd").id_for(p)
	if not costume.is_empty():return "costume_v04:"+costume
	if preload("res://scripts/job_art.gd").has_sprite(p):return "jobs:"+str(p.class_id)
	var key=avatar(p)
	if preload("res://scripts/combat_sprite_art.gd").AVATARS.has(key):return "motions:"+preload("res://scripts/combat_sprite_art.gd").AVATARS[key]
	return "gat:"+key
static func launch_offset(p:Dictionary,direction:Vector2)->Vector2:
	var presentation=preload("res://scripts/character_presentation.gd")
	var config=presentation.profile(presentation_id(p))
	var strong=p.get("motion","") in ["slam","shoot_high","cast_high"]
	var raw=config.get("strong_offset" if strong else "release_offset",[32,-70])
	var offset=Vector2(raw[0],raw[1])/float(config.get("height_scale",1.))
	var copy=p.duplicate();copy.aim=direction;copy.motion_aim=direction
	var pose=presentation.pose(copy)
	var animated=not presentation_id(p).begins_with("gat:")
	var side=-1 if preload("res://scripts/dungeon.gd").iso(direction).x<0 else 1
	var index=preload("res://scripts/combat_sprite_art.gd").index_for(p,0)
	var source=float(config.get("source_facing_by_frame",{}).get(str(index),config.get("source_facing",1)))
	return pose.offset+(offset*Vector2(side*source,1)).rotated(pose.angle*(.35 if animated else 1.))
static func _frame(p:Dictionary,time:float)->Dictionary:
	if preload("res://scripts/costume_art_v04.gd").has_sprite(p):return preload("res://scripts/costume_art_v04.gd").frame(p,time)
	if preload("res://scripts/job_art.gd").has_sprite(p):return preload("res://scripts/job_art.gd").frame(p,time)
	initialize();var key=avatar(p);var entry=catalog[key];var index=1 if fposmod(time,4.0)>3.82 else 0
	if preload("res://scripts/combat_sprite_art.gd").AVATARS.has(key):return preload("res://scripts/combat_sprite_art.gd").frame(key,p,time)
	if p.get("motion_time",0)>0:
		var progress=clampf(1-p.motion_time/p.motion_duration,0,1)
		index=[2,3,3,0][mini(3,int(progress*4))]
	var foot=entry.frames[index].foot
	return {"texture":texture(key,index),"foot":Vector2(foot[0],foot[1]),"height":float(entry.get("body_height",entry.height)),"index":index,"animated":false}
static func portrait(p:Dictionary)->AtlasTexture:
	if preload("res://scripts/costume_art_v04.gd").has_sprite(p):return preload("res://scripts/costume_art_v04.gd").portrait(p)
	if preload("res://scripts/job_art.gd").has_sprite(p):return preload("res://scripts/job_art.gd").portrait(p)
	initialize();var key=avatar(p);var cache_key=key+"portrait"
	if not textures.has(cache_key):
		var entry=catalog[key];var base=entry.frames[0];var h=float(entry.height);var r=base.rect
		var x=clampf(r[0]+base.foot[0]-h*.29,r[0],r[0]+r[2]-h*.58)
		var atlas=AtlasTexture.new();atlas.atlas=load(entry.sheet);atlas.region=Rect2(x,r[1]+h*.025,h*.58,h*.58);atlas.filter_clip=true;textures[cache_key]=atlas
	return textures[cache_key]
