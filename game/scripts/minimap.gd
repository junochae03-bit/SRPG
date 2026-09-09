extends Node2D
const Icons=preload("res://scripts/icon_library.gd")
const CENTER=Vector2(1324,106)
const ORIGIN=CENTER-Vector2(19,19)*3.0
var game
var static_map:StaticMap
var static_context:Array=[]
var static_builds=0

class StaticMap extends Node2D:
	var floor_points:Array=[]
	var fixed_markers:Array=[]
	var font:Font
	var draws=0
	func _draw():
		draws+=1
		draw_circle(Vector2(1324,106),78,Color("1d5146d9"))
		draw_arc(Vector2(1324,106),78,0,TAU,64,Color("b9d4b8"),2,true)
		for at in floor_points:draw_rect(Rect2(at,Vector2(3,3)),Color("a5b999"))
		for entry in fixed_markers:draw_texture_rect(entry.texture,entry.rect,false)
		draw_string(font,Vector2(1319,46),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eaf1da"))

func _ready():
	static_map=StaticMap.new();static_map.show_behind_parent=true
	static_map.material=preload("res://scripts/gat_art.gd").material()
	static_map.hide()
	add_child(static_map)

func can_show()->bool:
	return game!=null and game.session.connected and not (game.bag.visible or game.help_panel.visible or game.skill_tree.visible or game.town_panel.visible or game.codex.visible or game.npc_dialogue.visible)

func marker_rect(world:Vector2,pixels:float,clamp_to_edge:bool=false)->Rect2:
	var at=ORIGIN+world*3.0;var limit=73-pixels*.5
	if at.distance_to(CENTER)>limit:
		if not clamp_to_edge:return Rect2()
		at=CENTER+(at-CENTER).limit_length(limit)
	return Rect2(at-Vector2.ONE*pixels*.5,Vector2.ONE*pixels)

func refresh_static():
	# Dungeon geometry is fixed after generation; a new map has a new instance.
	# Camera/actor motion does not invalidate retained CanvasItem commands.
	var map=game.dungeon
	var context=[map.get_instance_id(),map.zone,map.floor_number,map.spawn,map.floor_cells.size(),game.fonts]
	if context==static_context:return
	static_context=context;static_builds+=1
	static_map.floor_points.clear();static_map.fixed_markers.clear();static_map.font=game.fonts
	for cell in map.floor_cells:
		var at=ORIGIN+Vector2(cell)*3.0
		if at.distance_to(CENTER)<73:static_map.floor_points.append(at)
	static_map.fixed_markers.append({"texture":Icons.texture("town"),"rect":marker_rect(map.spawn,12,true)})
	if map.zone=="town":
		for key in preload("res://scripts/world_catalog.gd").FACILITIES:
			var facility=preload("res://scripts/world_catalog.gd").FACILITIES[key];var rect=marker_rect(facility.pos,13)
			if rect.has_area():static_map.fixed_markers.append({"texture":Icons.texture(key),"rect":rect})
	static_map.queue_redraw()

func _draw():
	if static_map==null:return
	static_map.visible=can_show()
	if not static_map.visible:return
	refresh_static()
	if game.dungeon.zone!="town" and game.dungeon.floor_number>0:
		var sealed=game.session.state.enemies.values().any(func(e):return e.get("guardian",false) and e.hp>0)
		marker(game.dungeon.exit_position,"locked" if sealed else "stairs",15,Color.WHITE,true)
	for e in game.session.state.enemies.values():
		if e.hp<=0:continue
		if e.get("boss",false) or e.get("guardian",false):marker(e.pos,"boss",13)
		elif e.get("elite",false):marker(e.pos,"elite",10)
		else:
			var at=ORIGIN+e.pos*3.0
			if at.distance_to(CENTER)<71:draw_circle(at,1.6,Color("dc8c8b"))
	for p in game.session.state.players.values():marker(p.pos,"class_"+p.class_id,16,Color.WHITE,true)

func marker(world:Vector2,key:String,pixels:float,tint:Color=Color.WHITE,clamp_to_edge:bool=false):
	var rect=marker_rect(world,pixels,clamp_to_edge)
	if rect.has_area():Icons.draw(self,key,rect,tint)
