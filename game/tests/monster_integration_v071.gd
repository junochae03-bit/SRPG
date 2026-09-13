extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Ecology=preload("res://scripts/monster_ecology_v071.gd")
const World=preload("res://scripts/world_catalog.gd")
const Data=preload("res://scripts/exploration_crafting_data.gd")
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var simulations={};var spawned=0
	for kind in Ecology.data().monsters:
		var floor_id=int(Ecology.data().monsters[kind].appearances.keys()[0])
		if not simulations.has(floor_id):
			var cfg=preload("res://scripts/abyss_catalog.gd").config(floor_id)
			simulations[floor_id]=Sim.new(711+floor_id,cfg.terrain,floor_id)
			for enemy in simulations[floor_id].enemies.values():
				if Ecology.recognizes(enemy.kind):spawned+=1
		var sim=simulations[floor_id];sim.enemies.clear();sim.players.clear();sim.drops.clear();sim.monster_ecology.shots.clear();sim.monster_ecology.pending.clear()
		var p=sim.add_player(1,"통합 검사");p.pos=Vector2(sim.map.rooms[4]);p.hp=100000;p.max_hp=100000;p.stamina=0;p.invulnerable=0
		var e=sim.spawn_enemy(kind,p.pos+Vector2(.7,0),floor_id)
		var expected=Ecology.stats(kind,floor_id)
		check(e.max_hp==expected.health and e.damage==expected.damage and e.speed==expected.speed,"exact authored floor stats "+kind)
		check(World.display_height(kind)==float(Ecology.definition(kind).height),"art and hit geometry share body height "+kind)
		check(Geometry.circle(e,e.pos+Vector2(Geometry.radius(e)+.2,0),.3),"attack reaches body edge "+kind)
		check(sim.monster_ecology.begin(e,p.pos) and e.windup>0,"authored windup begins "+kind)
		var before=p.hp;var windup=e.windup
		sim.tick(windup*.45);check(p.hp==before,"telegraph before damage "+kind)
		for tick in range(45):sim.tick(.04)
		check(p.hp<before,"actual simulation applies hit "+kind)
		check(sim.snapshot(1).has("enemy_projectiles"),"projectile snapshot contract "+kind)
		sim.monster_ecology.cancel(e);e.cooldown=0;sim.monster_ecology.begin(e,p.pos);e.hp=0
		sim.tick(.01);check(sim.monster_ecology.shots.is_empty() and sim.monster_ecology.pending.is_empty() and e.windup==0,"dead enemy cancels attack "+kind)
		for attempt in range(35):
			sim.drops.clear();e.hp=0;sim.reward_kill(1,e,sim.balance.enemies[kind])
			var material_counts={}
			for drop in sim.drops.values():
				check(drop.owner==1,"personal drop owner")
				if drop.item.category!="material":continue
				var key=drop.item.material
				check(preload("res://scripts/content.gd").MATERIALS.has(key),"drop material registered "+key)
				material_counts[key]=int(material_counts.get(key,0))+1
				check(material_counts[key]==1,"dedicated and regional drops do not duplicate "+key)
	check(spawned>0,"authored monsters appear in generated encounters")
	print("MONSTER_INTEGRATION_V071 checks=%d failures=%d spawned=%d"%[checks,failures.size(),spawned]);quit(0 if failures.is_empty() else 1)
