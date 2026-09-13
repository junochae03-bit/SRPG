extends RefCounted
## Geometry follows solid terrain, never the moving fog boundary.
const Dungeon=preload("res://scripts/dungeon.gd")
const MAX_SUPPORTS=2
var edges:Array=[]
var edges_by_cell:Dictionary={}
func rebuild(map):
	edges.clear();edges_by_cell.clear()
	if map.floor_number<=0:return
	for cell in map.floor_cells:
		for direction in [Vector2i.LEFT,Vector2i.UP]:
			var solid=cell+direction
			if map.floor_cells.has(solid):continue
			var midpoint=Vector2(cell)+Vector2(direction)*.5
			var side=Vector2(direction).orthogonal()*.5
			var height=16.+posmod(cell.x*31+cell.y*17,13)
			edges.append({"cell":cell,"solid":solid,"a":Dungeon.iso(midpoint-side),"b":Dungeon.iso(midpoint+side),"height":height})
			if not edges_by_cell.has(cell):edges_by_cell[cell]=[]
			edges_by_cell[cell].append(edges.back())
func supports(map,clearance:Callable=Callable())->Array:
	var result=[]
	if map.floor_number<=0 or map.raid_arena or int((map.floor_number-1)/10) not in [0,1,2,3,6]:return result
	for room in [1,4]:
		var center=Vector2(map.rooms[room]);var best={};var distance=INF
		for edge in edges:
			var pos=Vector2(edge.solid+(edge.solid-edge.cell)*2);var d=pos.distance_squared_to(center)
			if clearance.is_valid() and not clearance.call(pos):continue
			if pos.distance_to(map.spawn)<7 or d>=distance:continue
			best=edge;distance=d
		if best.is_empty():continue
		var pos=Vector2(best.solid+(best.solid-best.cell)*2)
		if result.any(func(prop):return prop.pos.distance_to(pos)<8.):continue
		result.append({"pos":pos,"art_id":"cave_mine_arch","size":126.,"flip":room==4,"render_id":0,"alpha":1.,"explorer_trace":true})
	return result.slice(0,MAX_SUPPORTS)
func draw(game):
	if game.dungeon.floor_number<=0:return
	var art=preload("res://scripts/environment_art.gd").frame("cave_ore_boulders")
	var offset=-game.camera_pos+game.screen_center()
	var view=game.get_viewport().canvas_transform.affine_inverse()*game.get_viewport_rect()
	var drawn=0
	var visible_edges=[]
	for cell in game.vision.visible_cells:
		if edges_by_cell.has(cell):visible_edges.append_array(edges_by_cell[cell])
	for edge in visible_edges:
		if posmod(edge.cell.x*31+edge.cell.y*17,3)!=0 or not game.vision.sees(Vector2(edge.cell)):continue
		var point=Dungeon.iso(Vector2(edge.solid))+offset
		if not view.grow(40).has_point(point):continue
		var scale=(42.+float(edge.height)*.65)/art.height
		var rect=Rect2(point-art.foot*scale,art.texture.get_size()*scale)
		game.draw_texture_rect(art.texture,rect,false,Color(.65,.71,.72,.86))
		drawn+=1
		if drawn>=24:break
static func configuration()->Dictionary:
	return {"terrain":"solid physical cells only; sparse authored rock silhouettes","visible_rock_maximum":24,"trace_maximum":MAX_SUPPORTS,"trace_biomes":[0,1,2,3,6],"raid_traces":false,"light_reveals_fog":false,"collision_change":false}
