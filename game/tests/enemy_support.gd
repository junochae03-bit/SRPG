extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Support=preload("res://scripts/enemy_support.gd")
const Party=preload("res://scripts/party_rules.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture(depth:int=22,count:int=1):
	var sim=Sim.new(772,"cave",depth);sim.enemies.clear();sim.map.floor_cells.clear();sim.map.spawn=Vector2.ONE
	for x in range(1,30):
		for y in range(1,30):sim.map.floor_cells[Vector2i(x,y)]=true
	for id in range(1,count+1):
		var p=sim.add_player(id,"수련");p.pos=Vector2(12,8);p.invulnerable=10000.
	var healer=sim.spawn_enemy("goblin_shaman",Vector2(10,10),1);healer.ability_cd=0.;healer.cooldown=10000.;healer.encounter_room=1
	var ally=sim.spawn_enemy("skeleton",Vector2(12,10),1);ally.stun_time=10000.;ally.encounter_room=1
	Party.rescale(sim);ally.hp=roundi(ally.max_hp*.4)
	return sim
func advance(sim,seconds:float):
	for index in range(ceili(seconds/.05)):sim.tick(.05)
func _initialize():
	for depth in [2,22,99]:
		for count in [1,6]:
			var sim=fixture(depth,count);var healer=sim.enemies[1];var ally=sim.enemies[2];var before=ally.hp
			sim.tick(.05)
			check(healer.has("support_cast") and ally.hp==before,"actual tick starts visible windup before healing")
			advance(sim,1.)
			var ratio=float(ally.hp-before)/ally.max_hp
			check(ratio>.07 and ratio<=.081,"scaled healing meaningful B%d party%d"%[depth,count])
			check(healer.ability_cd>5. and not healer.has("support_cast"),"cooldown only follows completed cast")
			check(healer.get("attack_motion_kind","")=="support" and preload("res://scripts/monster_motion_art_v06.gd").pose_index(healer)==0,"healing release never displays an offensive strike")
			advance(sim,40.)
			check(float(ally.hp-before)/ally.max_hp<=.241 and float(ally.get("support_received",0))>.21,"per-recipient budget stops indefinite healing")
	var sim=fixture();var healer=sim.enemies[1];var ally=sim.enemies[2];var before=ally.hp
	sim.tick(.05);healer.stun_time=.01;sim.tick(.05)
	check(ally.hp==before and not healer.has("support_cast"),"even stun expiring this tick cancels cast")
	healer.ability_cd=0.;sim.tick(.05);healer.taunt_time=2.;healer.taunt_owner=1;sim.tick(.05)
	check(not healer.has("support_cast") and ally.hp==before,"taunt interrupts support")
	healer.taunt_time=0.;healer.ability_cd=0.;sim.tick(.05);healer.support_cast=.01;healer.taunt_time=.01;sim.tick(.05)
	check(not healer.has("support_cast") and ally.hp==before,"taunt expiring this tick still interrupts finishing cast")
	healer.taunt_time=0.;healer.ability_cd=0.;ally.hp=ally.max_hp;sim.events.clear();advance(sim,.5)
	check(not healer.has("support_cast") and healer.ability_cd==0. and sim.events.is_empty(),"full allies spend neither cooldown nor effects")
	ally.hp=before;ally.encounter_room=2;advance(sim,.5)
	check(not healer.has("support_cast"),"cannot heal neighboring encounter")
	ally.encounter_room=1
	for y in range(1,30):sim.map.floor_cells.erase(Vector2i(11,y))
	advance(sim,.5)
	check(ally.hp==before and not healer.has("support_cast"),"no healing through a wall")
	for y in range(1,30):sim.map.floor_cells[Vector2i(11,y)]=true
	healer.pos=Vector2(10,10);healer.ability_cd=0.;sim.tick(.3)
	check(healer.has("support_cast"),"cast resumes after wall removed")
	ally.hp=0;sim.tick(.05)
	check(not healer.has("support_cast") and ally.hp==0,"dead target never revived")
	sim=fixture();healer=sim.enemies[1];ally=sim.enemies[2];sim.tick(.05);sim.players[1].network_leaving=true;advance(sim,1.)
	check(not healer.has("support_cast") and not ally.has("support_received"),"departure removes threat and cancels healing")
	sim=fixture();healer=sim.enemies[1];ally=sim.enemies[2];ally.pos=Vector2(15,10);var origin=healer.pos
	advance(sim,.5)
	check(healer.pos.x>origin.x and healer.pos.y>=origin.y-.001,"support seeks injured ally without player-directed zigzag")
	check(healer.pos.distance_to(origin)<=healer.get("speed",sim.balance.enemies[healer.kind].speed)*.501,"support respects actual scaled movement speed")
	sim=fixture();healer=sim.enemies[1];ally=sim.enemies[2];ally.guardian=true;advance(sim,.5)
	check(not healer.has("support_cast"),"guardian excluded from support budget")
	ally.erase("guardian");ally.kind="goblin_shaman";advance(sim,.5)
	check(not healer.has("support_cast"),"healers cannot sustain each other")
	sim=fixture();healer=sim.enemies[1];ally=sim.enemies[2]
	var second=sim.spawn_enemy("goblin_shaman",Vector2(10,12),1);second.encounter_room=1;second.ability_cd=0.;second.cooldown=10000.
	advance(sim,1.2)
	check(float(ally.get("support_received",0))<=.081,"simultaneous healers share target lock")
	check(sim.snapshot(1).enemies[2].get("support_received",0)>0,"authoritative support state copied into snapshots")
	for cause in ["wall","distance","death","hazard"]:
		sim=fixture();healer=sim.enemies[1];ally=sim.enemies[2];before=ally.hp;sim.tick(.05)
		check(healer.has("support_cast"),"cast active before "+cause)
		match cause:
			"wall":sim.map.floor_cells.erase(Vector2i(11,10))
			"distance":ally.pos=Vector2(16,10)
			"death":healer.hp=0
			"hazard":
				healer.hazard_since=sim.clock-1.
				sim.combat.skills.zones=[{"owner":1,"amount":10,"pulses":[100.],"radius":3.,"pos":healer.pos,"elapsed":0.,"slow":0.,"stun":0.}]
		sim.tick(.05)
		check(not healer.has("support_cast") and ally.hp==before,"actual tick cancels without healing: "+cause)
		check(healer.ability_cd<Support.COOLDOWN,"interruption never spends full successful cooldown: "+cause)
	print("ENEMY_SUPPORT checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
