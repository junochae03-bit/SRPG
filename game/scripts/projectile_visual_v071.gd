extends Node2D
## Render-only projectile bodies and accepted-hit decorations. No simulation writes.
const Dungeon=preload("res://scripts/dungeon.gd")
const Presentation=preload("res://scripts/character_presentation.gd")
const Costume=preload("res://scripts/costume_art_v04.gd")
const VfxCatalog=preload("res://scripts/skill_vfx_catalog.gd")
static var catalog:Dictionary={}
static var impacts:Dictionary={}
var commands:Array=[]
var sheets:Dictionary={}
var trails:Dictionary={}
var impact_layer:Node2D
class ImpactLayer extends Node2D:
	var source
	func _draw():source.draw_commands(self,true)

static func data()->Dictionary:
	if catalog.is_empty(): catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/projectiles_v071/catalog.json"))
	return catalog

static func family(shot:Dictionary)->String:
	var explicit=str(shot.get("visual_family",""))
	if not explicit.is_empty(): return explicit if data().families.has(explicit) else ""
	var kind=str(shot.get("type",""))
	if kind in ["projectile_launch","projectile_impact"]: kind=str(shot.get("projectile_type",""))
	if kind in ["wave","card"]: return ""
	if shot.get("class_id","")=="gambler": return ""
	if shot.has("skill_id") or shot.has("skill_mode") or shot.has("vfx") or shot.has("fx"):
		var style=str(VfxCatalog.profile(shot).get("family",""))
		if style=="cards": return ""
		if style in ["fire","frost","thunder"]: return style
		if style=="vortex": return "shadow"
	if kind in ["bow","piercing"]: return "bolt" if shot.get("class_id","")=="hunter" else "arrow"
	if kind in ["bolt","dagger"]: return kind
	if kind=="staff": return "arcane"
	return ""

static func flight(shot:Dictionary)->Dictionary:
	var key=family(shot)
	if key.is_empty(): return {}
	var dir:Vector2=shot.get("dir",Vector2.RIGHT)
	if not dir.is_finite() or dir.length_squared()<.0001: return {}
	var age=maxf(0,float(shot.get("age",0)))
	var row:Dictionary=data().families[key]
	var projected=Dungeon.iso(dir.normalized())
	var traveled=Dungeon.iso(shot.get("pos",Vector2.ZERO)-shot.get("visual_start",shot.get("pos",Vector2.ZERO))).length()
	var speed=maxf(0,float(shot.get("speed",0)))*projected.length()
	return {"family":key,"frame":int(floor(age*float(row.loop_fps)))%4,"angle":projected.angle(),
		"trail_length":minf(traveled,minf(76.,speed*.055)),"offset":Presentation.projectile_offset(shot)}

func _ready():
	var mat=ShaderMaterial.new()
	mat.shader=preload("res://shaders/projectile_visual_v071.gdshader")
	material=mat
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=-2
	impact_layer=ImpactLayer.new();impact_layer.source=self
	impact_layer.material=material;impact_layer.texture_filter=texture_filter
	impact_layer.z_as_relative=false;impact_layer.z_index=0
	add_child(impact_layer)

func begin_frame(game=null):
	commands.clear()
	if game!=null and material!=null:
		material.set_shader_parameter("enabled",game.vision.active)
		material.set_shader_parameter("sight_mask",game.vision.texture)
		material.set_shader_parameter("mask_size",float(game.vision.extent))
		material.set_shader_parameter("camera",game.camera_pos)
		material.set_shader_parameter("screen_anchor",game.screen_center())
	queue_redraw()
	if impact_layer!=null:impact_layer.queue_redraw()

func sheet(path:String,key:String="alpha")->Texture2D:
	var id=path+"|"+key
	if not sheets.has(id): sheets[id]=Costume._sheet_texture(path,key) if key!="alpha" else load(path)
	return sheets[id]

func trail(key:String)->Texture2D:
	if not trails.has(key):
		var color=Color(data().families[key].trail_color)
		var gradient=Gradient.new()
		gradient.set_color(0,Color(color,0))
		gradient.set_color(1,Color(color,.45))
		var tex=GradientTexture2D.new()
		tex.gradient=gradient;tex.width=64;tex.height=4
		tex.fill_from=Vector2(0,.5);tex.fill_to=Vector2(1,.5)
		trails[key]=tex
	return trails[key]

func render_shot(game,shot:Dictionary)->bool:
	var sample=flight(shot)
	if sample.is_empty(): return false
	var row:Dictionary=data().families[sample.family]
	var frame:Dictionary=row.frames[sample.frame]
	var at:Vector2=game.world_point(shot.pos)+sample.offset
	# Trail reaches only previously traveled space; never paints behind spawn.
	if sample.trail_length>1:
		commands.append({"texture":trail(sample.family),"rect":Rect2(0,0,64,4),"at":at,"pivot":Vector2(64,2),"scale":Vector2(sample.trail_length/64.,1),"angle":sample.angle,"offset":sample.offset,"alpha":.7,"black":false})
	var r=frame.rect
	commands.append({"texture":sheet(row.sheet,row.key),"rect":Rect2(r[0],r[1],r[2],r[3]),"at":at,"pivot":Vector2(frame.tip[0],frame.tip[1]),"scale":Vector2.ONE*float(row.scale),"angle":sample.angle,"offset":sample.offset,"alpha":1.,"black":false})
	queue_redraw()
	return true

func render_event(game,event:Dictionary,t:float,duration:float)->bool:
	var kind=str(event.get("type",""))
	if kind not in ["projectile_launch","projectile_impact"]: return false
	var key=family(event)
	if key.is_empty(): return false
	if t<0 or duration<=0 or t>=duration or event.get("cancelled",false): return true
	if impacts.is_empty(): impacts=JSON.parse_string(FileAccess.get_file_as_string("res://assets/attacks/catalog.json"))
	var row:Dictionary=impacts.animations[data().families[key].impact_id]
	var progress=t/duration
	var frame:Dictionary=row.frames[mini(5,int(progress*6))]
	var r=frame.rect
	var size=30. if kind=="projectile_launch" else 68. if key in ["arrow","bolt","dagger"] else 96.
	var extent=1.0
	for f in row.frames: extent=maxf(extent,maxf(f.rect[2],f.rect[3]))
	var offset:Vector2=event.get("visual_offset",event.get("visual_origin",Vector2(0,-70)))
	commands.append({"texture":sheet(row.sheet),"rect":Rect2(r[0],r[1],r[2],r[3]),"at":game.world_point(event.pos)+offset,
		"pivot":Vector2(frame.pivot[0],frame.pivot[1]),"scale":Vector2.ONE*size/extent,"angle":0.,"offset":offset,"alpha":.75*(1-progress),"black":true,"front":kind=="projectile_impact"})
	queue_redraw()
	if impact_layer!=null:impact_layer.queue_redraw()
	return true

func _draw():
	draw_commands(self,false)

func draw_commands(surface:Node2D,front:bool):
	for c in commands:
		if c.get("front",false)!=front:continue
		var rect:Rect2=c.rect
		var corners=[Vector2.ZERO,Vector2(rect.size.x,0),rect.size,Vector2(0,rect.size.y)]
		var vertices=PackedVector2Array()
		var uv=PackedVector2Array()
		for corner in corners:
			vertices.append(c.at+((corner-c.pivot)*c.scale).rotated(c.angle))
			uv.append((rect.position+corner.clamp(Vector2(.5,.5),rect.size-Vector2(.5,.5)))/c.texture.get_size())
		var encoded=Color(.5+c.offset.x/2048.,.5+c.offset.y/2048.,1. if c.black else 0.,c.alpha)
		surface.draw_polygon(vertices,PackedColorArray([encoded]),uv,c.texture)
