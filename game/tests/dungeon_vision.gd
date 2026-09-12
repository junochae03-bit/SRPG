extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
const Vision=preload("res://scripts/dungeon_vision.gd")
var checks=0
var failures:Array=[]
func check(value:bool,message:String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize():
	var map=Dungeon.new(82,"cave",1);map.floor_cells.clear()
	for x in range(2,25):
		for y in range(2,16):
			if x!=11:map.floor_cells[Vector2i(x,y)]=true
	var sight=Vision.new();var players={1:{"pos":Vector2(8,8),"hp":120}}
	sight.update(map,players,0.)
	check(sight.sees(Vector2(10,8)),"visible approach")
	check(sight.sees(Vector2(11,8)),"first wall visible")
	check(not sight.sees(Vector2(12,8)),"opaque wall blocks enemies and terrain")
	check(not sight.discovered(Vector2(16,8)),"unvisited terrain unknown")
	players[1].pos=Vector2(20,8);sight.update(map,players,1.)
	check(not sight.sees(Vector2(8,8)) and sight.discovered(Vector2(8,8)),"sight lost immediately, map remembered")
	sight.update(map,players,2.)
	check(is_equal_approx(sight.brightness(Vector2i(8,8)),Vision.MEMORY_LIGHT),"explored minimap fades to dark memory")
	players[2]={"pos":Vector2(8,8),"hp":120};sight.update(map,players,3.)
	check(sight.sees(Vector2(8,8)) and sight.sees(Vector2(20,8)),"party shares current sight")
	players.erase(2);sight.update(map,players,4.)
	check(not sight.sees(Vector2(8,8)),"departed ally does not reveal")
	map.floor_cells[Vector2i(11,8)]=true;map.revision+=1;players[1].pos=Vector2(9,8);sight.update(map,players,5.)
	check(sight.sees(Vector2(13,8)),"opening a door recalculates sight without motion")
	var revision=sight.revision;sight.update(map,players,6.);revision=sight.revision;sight.update(map,players,7.)
	check(sight.revision==revision,"stationary settled fog does not rebuild")
	map.floor_number=2;sight.update(map,players,8.)
	check(not sight.discovered(Vector2(24,8)),"new floor starts unexplored")
	var replacement=Dungeon.new(82,"cave",2)
	players[1].pos=replacement.spawn;sight.update(replacement,players,9.)
	check(not sight.discovered(Vector2(20,8)),"same seed new expedition clears old memory")
	sight.reset();check(sight.explored.is_empty(),"disconnect clears memory")
	map.zone="town";sight.update(map,players,10.)
	check(sight.sees(Vector2(70,70)),"town remains visible")
	print("DUNGEON_VISION checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
