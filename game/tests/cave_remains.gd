extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
const Remains=preload("res://scripts/cave_remains.gd")
const Env=preload("res://scripts/environment_art.gd")
var checks=0
var failures=[]
class Sight:
	var allowed={}
	func sees(pos:Vector2)->bool:return allowed.has(pos)
class View:
	var vision=Sight.new()
	func world_point(pos:Vector2)->Vector2:return pos
	func screen_center()->Vector2:return Vector2.ZERO
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var total=0;var kinds={};var populated=0
	for depth in range(1,101):
		for seed_value in [571,9261]:
			var map=Dungeon.new(seed_value+depth*7919,"cave",depth)
			var cells=map.floor_cells.duplicate();var sites=map.exploration_sites.duplicate(true)
			var rows=map.ground_remains
			check(rows==Remains.generate(map),"deterministic dressing B%d"%depth)
			check(map.floor_cells==cells and map.exploration_sites==sites,"no collision, floor or reward mutation")
			check(rows.size()<=5,"bounded floor decoration")
			if depth%10==0:check(rows.is_empty(),"raid arena remains clear");continue
			if not rows.is_empty():populated+=1
			var used_rooms={}
			for i in range(rows.size()):
				var row=rows[i];kinds[row.kind]=true;total+=1
				check(map.walkable(row.pos),"remains lie on real cave floor")
				check(not used_rooms.has(row.room),"no piles repeated across the same room");used_rooms[row.room]=true
				check(row.pos.distance_to(map.spawn)>=8. and row.pos.distance_to(map.exit_position)>=8.,"entry and final approach clear")
				for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:check(map.walkable(row.pos+offset),"clear walking ring")
				for site in sites:check(row.pos.distance_to(site.pos)>=4.,"functional site clear")
				for cue in map.exploration_cues:
					for mark in cue.marks:check(row.pos.distance_to(mark.pos)>=3.,"meaningful route traces remain distinct")
				for j in range(i):check(row.pos.distance_to(rows[j].pos)>=8.,"sparse clusters")
			var view=View.new()
			check(Remains.visible(view,rows).is_empty(),"unknown and remembered cells do not reveal remains")
			if not rows.is_empty():
				view.vision.allowed[rows[0].pos]=true
				check(Remains.visible(view,rows).size()==1,"only currently seen cluster drawn")
			for region in map.hidden_regions:
				for row in rows:
					for key in ["pos","center","forward_exit"]:
						if region.has(key):check(row.pos.distance_to(region[key])>=4.,"hidden passage interaction stays clear")
				preload("res://scripts/hidden_rooms.gd").open(map,region.id)
			check(map.ground_remains==rows,"opening shortcuts does not shuffle scenery")
	check(populated>=160,"remains present without forcing filler into invalid locations")
	check(kinds.size()==4,"all four actual sprites are used")
	for key in kinds:
		var tex=Remains.texture(key);check(tex.atlas.get_image().detect_alpha()!=Image.ALPHA_NONE,"real alpha "+key)
		check(Rect2(Vector2.ZERO,tex.atlas.get_size()).encloses(tex.region),"atlas region inside source")
	check(Remains.generate(Dungeon.new(19,"town",0)).is_empty(),"town not littered with monster bones")
	for floor_number in [11,21,41,61,81,91]:
		var pool=Env.ids("cave",floor_number)
		for id in pool:
			check(not ["arch","gate","column","tower","cart","altar","brazier","pylon","orrery","lantern","beacon","bench"].any(func(word):return id.contains(word)),"no repeated decorative architecture "+id)
	print("CAVE_REMAINS population=%d/180 clusters=%d"%[populated,total])
	print("CAVE_REMAINS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
