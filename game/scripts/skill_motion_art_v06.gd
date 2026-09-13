extends RefCounted
## Authored poses follow the simulation's cast and release, never a preview clock.
const PATH="res://assets/skill_motions_v06/catalog.json"
const Art=preload("res://scripts/costume_art_v04.gd")
const Vfx=preload("res://scripts/skill_vfx_catalog.gd")
static var data:Dictionary={}
static var textures:Dictionary={}
static var measurements:Dictionary={}

static func body_height(id:String)->float:
	if measurements.is_empty():measurements=JSON.parse_string(FileAccess.get_file_as_string("res://assets/skill_motions_v06/calibration.json"))
	return float(measurements.sprites[id].body_height)

static func foot_for(id:String,index:int)->Array:
	body_height(id)
	return measurements.sprites[id].get("frame_overrides",{}).get(str(index),{}).get("foot",catalog().sprites[id].frames[index].foot_estimate)

static func source_facing_for(id:String,index:int)->float:
	body_height(id)
	return float(measurements.sprites[id].get("frame_overrides",{}).get(str(index),{}).get("source_facing",1.))

static func catalog()->Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data

static func sprite_id(class_id:String)->String:
	return str(catalog().aliases.get(class_id,class_id))

static func row_for(class_id:String,node:Dictionary)->int:
	var entry=catalog().sprites.get(sprite_id(class_id),{})
	if entry.is_empty():return -1
	var family=Vfx.family_for({"class_id":class_id,"skill_id":node.get("id",""),"skill_mode":node.get("mode",""),"fx":node.get("fx","")})
	var rows=[]
	for action in entry.actions:
		if action.family==family:rows.append(int(action.row))
	# Each profession has a safe primary casting gesture for unsupported families.
	return int(rows[posmod(int(node.get("index",0)),rows.size())]) if not rows.is_empty() else 0

static func start(p:Dictionary,node:Dictionary,windup:bool=false):
	var row=row_for(str(p.class_id),node)
	if row<0:p.erase("skill_motion");return
	p["skill_motion"]={"class_id":p.class_id,"skill_id":node.id,"row":row,"windup":windup,"duration":p.motion_duration,"motion":p.motion}
	p.motion_aim=p.aim;p.motion_aim_motion=p.motion;p.motion_aim_duration=p.motion_duration

static func selection(p:Dictionary)->Dictionary:
	if p.get("avatar","auto")!="auto" or p.get("costume","none") not in ["none",""] or Art.has_sprite(p):return {}
	if p.get("hp",1)<=0 or p.get("hurt_time",0)>0 or p.get("dodge_time",0)>0 or p.get("down_time",0)>0 or p.get("charge_time",-1)>=0:return {}
	var state=p.get("skill_motion",{})
	if state.is_empty() or state.class_id!=p.get("class_id",""):return {}
	var remaining=float(p.get("motion_time",0));var duration=float(state.duration)
	var phase=2
	if state.windup:
		var casting=p.get("job_state",{}).get("casting",{})
		if casting.is_empty() or casting.get("node",{}).get("id","")!=state.skill_id:return {}
		remaining=float(casting.time)
		phase=0 if remaining>duration*.65 else 1
	else:
		if p.get("motion","")!=state.motion or p.get("motion_duration",-1)!=duration:return {}
		phase=2 if remaining>duration*.45 else 3
	if remaining<=0:return {}
	return {"id":sprite_id(str(p.class_id)),"index":int(state.row)*4+phase,"phase":phase}

static func frame(p:Dictionary,_time:float)->Dictionary:
	var selected=selection(p)
	if selected.is_empty():return {}
	var entry=catalog().sprites[selected.id];var f=entry.frames[selected.index]
	var key=selected.id+":"+str(selected.index)
	if not textures.has(key):
		var sheet=Art._sheet_texture(entry.sheet,"green")
		if sheet==null:return {}
		var t=AtlasTexture.new();t.atlas=sheet;t.region=Rect2(f.rect[0],f.rect[1],f.rect[2],f.rect[3]);t.filter_clip=true;textures[key]=t
	var height=body_height(selected.id)
	var foot=foot_for(selected.id,selected.index)
	return {"texture":textures[key],"foot":Vector2(foot[0],foot[1]),"height":height,"body_pixels":112.,"index":selected.index,"animated":true,"source_facing":source_facing_for(selected.id,selected.index),"presentation_id":"skill_motion_v06:"+selected.id,"skill_phase":selected.phase}
