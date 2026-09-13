extends RefCounted
const World=preload("res://scripts/world_catalog.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")

static func role(kind:String)->String:
	match World.ENEMIES[kind].ai:
		"healer":return "support"
		"ranged","spore":return "ranged"
		"charger":return "flanker"
	return "frontline"

static func apply(map):
	if map.floor_number<=0 or map.raid_arena:return
	var pool:Array=Abyss.config(map.floor_number).mobs
	var fronts=pool.filter(func(kind):return role(kind) in ["frontline","flanker"])
	var backs=pool.filter(func(kind):return role(kind) in ["ranged","support"])
	var without_healer=pool.filter(func(kind):return role(kind)!="support")
	var distances=ingress_distances(map)
	for room in range(1,8):
		var base=map.encounters.filter(func(entry):return entry.room==room and entry.role!="guardian" and not entry.get("risk_reinforcement",false))
		var extras=map.encounters.filter(func(entry):return entry.room==room and entry.get("risk_reinforcement",false))
		var used_support=false;var normal_index=0
		# Increasing risk never moves or replaces a base encounter. Reinforcements
		# use their own slots, while sharing the room's support limit.
		for group in [base,extras]:
			var positions=group.map(func(entry):return entry.pos)
			positions.sort_custom(func(a,b):
				var da=int(distances.get(Vector2i(a.round()),99999));var db=int(distances.get(Vector2i(b.round()),99999))
				if da!=db:return da<db
				return a.x<b.x if a.x!=b.x else a.y<b.y)
			for entry in group:
				var kind:String=entry.get("kind","")
				if entry.role=="elite":kind=Abyss.config(map.floor_number).elite
				elif kind.is_empty():
					var candidates=pool
					if normal_index==0 and not fronts.is_empty():candidates=fronts
					elif normal_index==1 and not backs.is_empty():candidates=backs
					kind=candidates[posmod(int(entry.mob_index)+room,candidates.size())]
					normal_index+=1
				if role(kind)=="support" and used_support:kind=without_healer[posmod(int(entry.mob_index)+room,without_healer.size())]
				used_support=used_support or role(kind)=="support"
				entry["kind"]=kind;entry["combat_role"]=role(kind)
			group.sort_custom(func(a,b):return priority(a.combat_role)<priority(b.combat_role))
			for index in range(group.size()):group[index].pos=positions[index]

static func priority(value:String)->int:
	return {"frontline":0,"flanker":1,"ranged":2,"support":3}.get(value,0)

static func ingress_distances(map)->Dictionary:
	var origin=Vector2i(map.spawn.round());var distances={origin:0};var queue=[origin];var index=0
	while index<queue.size():
		var cell=queue[index];index+=1
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next=cell+direction
			if distances.has(next) or not map.walkable(Vector2(next)):continue
			distances[next]=distances[cell]+1;queue.append(next)
	return distances

static func configuration()->Dictionary:
	return {"scope":"normal_dungeon_rooms","role_order":["frontline","flanker","ranged","support"],"maximum_healers_per_room":1,"species_pool":"current_biome_only","frontline_and_backline":"when_available_in_biome","position_order":"walkable_distance_from_spawn","count_and_slot_geometry":"unchanged","risk_reinforcements":"same_room_healer_cap","ingress_scan":"once_at_generation"}
