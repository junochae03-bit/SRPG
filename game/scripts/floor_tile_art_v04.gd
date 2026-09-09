extends RefCounted

const CATALOG_PATH="res://assets/floor_tiles_v04/catalog.json"
static var data:Dictionary={}
static var atlas:Texture2D

static func catalog()->Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	return data

static func texture()->Texture2D:
	if atlas==null:atlas=load(catalog().atlas)
	return atlas

static func material(id:String)->Dictionary:
	return catalog().materials[id]

static func profile(zone:String,floor_number:int)->Dictionary:
	var c=catalog()
	var id=c.chapters[clampi(int((floor_number-1)/10),0,9)] if floor_number>0 else "town" if zone=="town" else "tutorial"
	var result:Dictionary=c.mappings[id].duplicate(true)
	result["id"]=id
	return result

static func panel(id:String)->Vector2:
	var rect=material(id).rect
	return Vector2(rect[0],rect[1])/512.0

static func tint(values:Array)->Vector3:
	return Vector3(values[0],values[1],values[2])

static func apply(shader_material:ShaderMaterial,zone:String,floor_number:int)->Dictionary:
	var selected=profile(zone,floor_number)
	shader_material.set_shader_parameter("material_atlas",texture())
	shader_material.set_shader_parameter("ground_panel",panel(selected.ground))
	shader_material.set_shader_parameter("path_panel",panel(selected.path))
	shader_material.set_shader_parameter("ground_tint",tint(selected.ground_tint))
	shader_material.set_shader_parameter("path_tint",tint(selected.path_tint))
	shader_material.set_shader_parameter("path_saturation",float(selected.path_saturation))
	return selected

# The same contract is used by CPU seam checks and the shader. Mirroring avoids
# discontinuities without editing generated pixels or sampling another panel.
static func sample_uv(world:Vector2,id:String)->Vector2:
	var phase=world/5.0
	var mirrored=Vector2(1.0-absf(fposmod(phase.x,2.0)-1.0),1.0-absf(fposmod(phase.y,2.0)-1.0))
	return (panel(id)*512.0+Vector2(16,16)+mirrored*480.0)/Vector2(1536,1024)
