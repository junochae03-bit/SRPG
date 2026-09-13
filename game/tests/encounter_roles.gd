extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
const Roles=preload("res://scripts/encounter_roles.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Risk=preload("res://scripts/expedition_risk.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	for depth in range(1,101):
		for risk in [0,Risk.cap(depth)]:
			var map=Dungeon.new(972+depth*91,"cave",depth,risk)
			if depth%10==0:
				check(map.encounters.size()==1 and map.encounters[0].role=="guardian","raid unchanged");continue
			var pool=Abyss.config(depth).mobs;var distances=Roles.ingress_distances(map)
			var original=map.encounters.duplicate(true)
			Roles.apply(map)
			check(map.encounters==original,"role assignment stable on repeat")
			var base=Dungeon.new(972+depth*91,"cave",depth,0)
			check(map.encounters.size()==base.encounters.size()+risk*2,"risk count unchanged")
			for room in range(1,8):
				var group=map.encounters.filter(func(entry):return entry.room==room)
				check(group.filter(func(entry):return Roles.role(entry.kind)=="support").size()<=1,"one healer including reinforcement")
				for entry in group:
					check(entry.kind in pool or entry.kind==Abyss.config(depth).elite,"biome species preserved")
					check(map.walkable(entry.pos) and distances.has(Vector2i(entry.pos.round())),"slot reachable")
					for other in group:
						if entry==other:continue
						check(entry.pos.distance_to(other.pos)>=1.999,"no new overlapping slots")
						if entry.get("risk_reinforcement",false)==other.get("risk_reinforcement",false) and Roles.priority(entry.combat_role)<Roles.priority(other.combat_role):
							check(distances[Vector2i(entry.pos.round())]<=distances[Vector2i(other.pos.round())],"rear role uses later actual ingress distance")
	print("ENCOUNTER_ROLES checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
