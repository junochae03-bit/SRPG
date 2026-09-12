extends RefCounted
## Authoritative gameplay sound: independent of audio playback, volume and UI.
const ATTACK_RADIUS=8
const HEAVY_RADIUS=12
const SKILL_RADIUS=10
const SPRINT_RADIUS=6
const SEARCH_SECONDS=5.0
const MAX_RESPONDERS=4
var sim_ref:WeakRef
var sim:
	get:return sim_ref.get_ref()
var emitted_at={}
var emitted_radius={}
func _init(owner_sim):sim_ref=weakref(owner_sim)
func emit(owner:int,position:Vector2,radius:int)->int:
	if sim.map.floor_number<=0 or sim.map.raid_arena:return 0
	var player=sim.players.get(owner,{})
	if player.is_empty() or player.hp<=0 or player.get("network_leaving",false):return 0
	radius+=int(sim.map.environment.get("noise_bonus",0))
	if sim.clock-float(emitted_at.get(owner,-100.))<.35 and int(emitted_radius.get(owner,0))>=radius:return 0
	emitted_at[owner]=sim.clock;emitted_radius[owner]=radius
	var origin=Vector2i(position.round());var distances={origin:0};var parents={};var queue=[origin];var index=0
	while index<queue.size():
		var cell=queue[index];index+=1
		if distances[cell]>=radius:continue
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next=cell+direction
			if distances.has(next) or not sim.map.walkable(Vector2(next)):continue
			distances[next]=distances[cell]+1;parents[next]=cell;queue.append(next)
	var candidates=[]
	for enemy in sim.enemies.values():
		if enemy.hp<=0 or enemy.get("guardian",false) or enemy.get("training",false) or enemy.get("windup",0)>0:continue
		var cell=Vector2i(enemy.pos.round())
		if not distances.has(cell) or enemy.home.distance_to(position)>18.:continue
		candidates.append(enemy)
	candidates.sort_custom(func(a,b):return a.pos.distance_squared_to(position)<b.pos.distance_squared_to(position))
	var count=0
	for enemy in candidates.slice(0,MAX_RESPONDERS):
		var cursor=Vector2i(enemy.pos.round());var path=[]
		while parents.has(cursor):cursor=parents[cursor];path.append(Vector2(cursor))
		enemy["search_path"]=path;enemy["search_until"]=sim.clock+SEARCH_SECONDS;enemy["heard_until"]=sim.clock+SEARCH_SECONDS+4.;enemy["awareness_state"]="search"
		count+=1
	return count
func action(p:Dictionary,kind:String):
	if kind=="attack":emit(p.id,p.pos,ATTACK_RADIUS)
	elif kind=="heavy":emit(p.id,p.pos,HEAVY_RADIUS)
	elif kind.begins_with("skill_") or kind=="nova":emit(p.id,p.pos,SKILL_RADIUS)
func movement(p:Dictionary,previous:Vector2):
	if p.get("sprint",false) and previous.distance_to(p.pos)>.001:emit(p.id,p.pos,SPRINT_RADIUS)
func investigate(enemy:Dictionary,speed:float,delta:float)->bool:
	if float(enemy.get("search_until",0))<=sim.clock:
		if enemy.get("awareness_state","") in ["search","engaged"]:
			enemy["search_path"]=route(enemy.pos,enemy.home);enemy["awareness_state"]="return"
		elif enemy.get("awareness_state","")!="return":return false
	var path:Array=enemy.get("search_path",[])
	if path.is_empty():
		if enemy.get("awareness_state","")=="return":enemy.erase("awareness_state");enemy.erase("search_until");return false
		return true
	if enemy.pos.distance_to(path[0])<.18:path.pop_front()
	if not path.is_empty():enemy.pos=sim.map.move(enemy.pos,enemy.pos.direction_to(path[0])*minf(enemy.pos.distance_to(path[0]),speed*delta))
	return true
func route(start:Vector2,end:Vector2)->Array:
	var origin=Vector2i(start.round());var goal=Vector2i(end.round());var queue=[origin];var visited={origin:true};var parents={};var index=0
	while index<queue.size():
		var cell=queue[index];index+=1
		if cell==goal:
			var path=[]
			while parents.has(cell):path.push_front(Vector2(cell));cell=parents[cell]
			if path.is_empty() or path.back()!=end:path.append(end)
			return path
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next=cell+direction
			if visited.has(next) or not sim.map.walkable(Vector2(next)):continue
			visited[next]=true;parents[next]=cell;queue.append(next)
	return []
static func configuration()->Dictionary:
	return {"attack_radius":ATTACK_RADIUS,"heavy_radius":HEAVY_RADIUS,"skill_radius":SKILL_RADIUS,"sprint_radius":SPRINT_RADIUS,"search_seconds":SEARCH_SECONDS,"max_responders":MAX_RESPONDERS,"propagation":"walkable_cell_distance","raid_guardian_lure":false,"audio_independent":true}
