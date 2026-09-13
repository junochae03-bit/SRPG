extends RefCounted
## Optional reader. Empty means the caller must keep the existing V04 action.
## Appearance ownership and class eligibility remain in the existing session.
const Legacy=preload("res://scripts/costume_art_v04.gd")
const PATH="res://assets/costume_v06/runtime.json"
static var _data:Dictionary={}
static var _loaded=false
static var _frames:Dictionary={}

static func catalog()->Dictionary:
	if not _loaded:
		_loaded=true
		if FileAccess.file_exists(PATH):
			var parsed=JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Dictionary and int(parsed.get("schema",0))==1:_data=parsed.get("entries",{})
	return _data

static func reset_cache(reload_catalog:bool=false):
	_frames.clear()
	if reload_catalog:_loaded=false;_data.clear()

static func action_for(p:Dictionary)->String:
	if float(p.get("down_time",0.))>0:return "down"
	return Legacy._action_for(Legacy.index_for(p,0.))

static func frame(p:Dictionary,time:float)->Dictionary:
	var id=Legacy.id_for(p)
	var entry:Dictionary=catalog().get(id,{})
	if entry.is_empty() or entry.get("role","")!="player_costume":return {}
	var action=action_for(p)
	var sequence:Dictionary=entry.get("sequences",{}).get(action,{})
	if not sequence.get("approved",false):return {}
	var poses:Array=entry.get("idle_playback",[]) if action=="idle" else sequence.get("poses",[])
	if poses.is_empty():return {}
	for pose in poses:
		if pose not in sequence.poses:return {}
	# Stable rest, a short blink, then rest. Do not flash through expressions at
	# walking speed or restart the sequence on every frame() call.
	var selected=0
	if action=="idle":
		var clock=fposmod(time,5.) if is_finite(time) else 0.
		selected=1 if clock>=4.72 and poses.size()>1 else 0
	elif action=="hurt" and poses.size()==1:
		# Hold the verified reaction only while the real hurt timer is active.
		selected=0
	else:
		# Other actions remain opt-in after their own phase/socket calibration.
		return {}
	var result=_frame_at(id,int(poses[selected]))
	if result.is_empty():return {}
	result=result.duplicate()
	result.index=Legacy.index_for(p,time)
	return result

## Explicit inspection entry for QA. Public frame() never enables candidates.
static func _frame_at(id:String,pose_id:int)->Dictionary:
	var entry:Dictionary=catalog().get(id,{})
	var f:Dictionary=entry.get("frames",{}).get(str(pose_id),{})
	if f.is_empty():return {}
	var key=id+":"+str(pose_id)
	if _frames.has(key):return _frames[key]
	var r=f.get("rect",[]);var foot=f.get("foot",[]);var height=float(f.get("body_height",0.))
	if r.size()!=4 or foot.size()!=2 or not is_finite(height) or height<=0:return {}
	var point=Vector2(foot[0],foot[1]);var region=Rect2(r[0],r[1],r[2],r[3])
	if not point.is_finite() or not region.position.is_finite() or not region.size.is_finite() or not region.has_area():return {}
	var texture=Legacy._sheet_texture(str(f.sheet),"green")
	if texture==null or not Rect2(Vector2.ZERO,texture.get_size()-Vector2.ONE).encloses(region):return {}
	var atlas=AtlasTexture.new();atlas.atlas=texture;atlas.region=region;atlas.filter_clip=true
	var result={"texture":atlas,"foot":point,"height":height,"body_pixels":112.,"animated":true,
		"index":15,"pose_id":pose_id,"source_index":int(f.source_index),"costume_id":id,
		"source_facing":float(f.source_facing),"action":str(f.action),"sheet":str(f.sheet),
		"frame_source_path":str(f.sheet),"expanded_costume":true}
	_frames[key]=result
	return result
