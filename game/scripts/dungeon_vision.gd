extends RefCounted
## Shared party sight. Unknown terrain is black; explored terrain stays dim.
const RADIUS=8
const MEMORY_LIGHT=.24
const FADE_SECONDS=.65
var visible_cells:Dictionary={}
var explored:Dictionary={}
var last_seen:Dictionary={}
var revision=0
var context=[]
var map_instance=0

func reset():
	context=[];map_instance=0;scenery_cache.clear();visible_cells.clear();explored.clear();last_seen.clear();revision+=1;active=false
var active=false
var time=0.
var last_change=-10.
var last_update=-10.
var image:Image
var texture:ImageTexture
var extent=0
var scenery_cache:Dictionary={}
const PAD=12

static func cell_at(pos:Vector2)->Vector2i:return Vector2i(roundi(pos.x),roundi(pos.y))
static func ray_visible(map,origin:Vector2i,target:Vector2i)->bool:
	var delta=target-origin;var steps=maxi(absi(delta.x),absi(delta.y))
	for index in range(1,steps+1):
		var at=cell_at(Vector2(origin)+Vector2(delta)*float(index)/float(steps))
		if at!=target and not map.floor_cells.has(at):return false
		var previous=cell_at(Vector2(origin)+Vector2(delta)*float(index-1)/float(steps))
		if at.x!=previous.x and at.y!=previous.y:
			if not map.floor_cells.has(Vector2i(at.x,previous.y)) and not map.floor_cells.has(Vector2i(previous.x,at.y)):return false
	return true

func update(map,players:Dictionary,now:float):
	time=now;active=map.floor_number>0 and map.zone!="town"
	var origins=[]
	for id in players:
		var p=players[id]
		if p.get("hp",0)>0 and not p.get("network_leaving",false):origins.append(cell_at(p.pos))
	origins.sort()
	var next=[map.seed_value,map.zone,map.floor_number,map.revision,origins]
	var different_map=map_instance!=map.get_instance_id() or context.is_empty() or context.slice(0,3)!=next.slice(0,3)
	if different_map:visible_cells.clear();explored.clear();last_seen.clear()
	if different_map or context!=next:
		map_instance=map.get_instance_id()
		# Preserve the instant sight was lost, not the time the party first arrived.
		for cell in visible_cells:last_seen[cell]=now
		visible_cells.clear();context=next;last_change=now
		if active:
			for origin in origins:
				for dx in range(-RADIUS,RADIUS+1):
					for dy in range(-RADIUS,RADIUS+1):
						if dx*dx+dy*dy>RADIUS*RADIUS:continue
						var cell=origin+Vector2i(dx,dy)
						if ray_visible(map,origin,cell):visible_cells[cell]=true;explored[cell]=true;last_seen[cell]=now
		refresh_texture(map);revision+=1;last_update=now
	elif now-last_change<FADE_SECONDS+.15 and now-last_update>=.10:
		refresh_texture(map);revision+=1;last_update=now

func sees(pos:Vector2)->bool:return not active or visible_cells.has(cell_at(pos))
func discovered(pos:Vector2)->bool:return not active or explored.has(cell_at(pos))
func brightness(cell:Vector2i)->float:
	if not active or visible_cells.has(cell):return 1.
	if not explored.has(cell):return 0.
	return lerpf(1.,MEMORY_LIGHT,clampf((time-float(last_seen.get(cell,-10.)))/FADE_SECONDS,0,1))
func scenery_brightness(pos:Vector2)->float:
	if not active:return 1.
	var cell=cell_at(pos)
	if scenery_cache.has(cell):return scenery_cache[cell]
	var light=brightness(cell)
	# Large boundary rocks/trees extend over the visible floor from opaque feet.
	for dx in range(-2,3):
		for dy in range(-2,3):light=maxf(light,brightness(cell+Vector2i(dx,dy)))
	scenery_cache[cell]=light;return light

func refresh_texture(map):
	scenery_cache.clear()
	var dimension=preload("res://scripts/dungeon.gd").SIZE+PAD*2
	if image==null or extent!=dimension:
		extent=dimension;image=Image.create(extent,extent,false,Image.FORMAT_RG8)
	image.fill(Color.BLACK)
	for cell in explored:
		var pixel=cell+Vector2i.ONE*PAD
		if pixel.x>=0 and pixel.y>=0 and pixel.x<extent and pixel.y<extent:image.set_pixelv(pixel,Color(brightness(cell),1. if visible_cells.has(cell) else 0.,0))
	if texture==null:texture=ImageTexture.create_from_image(image)
	else:texture.update(image)
