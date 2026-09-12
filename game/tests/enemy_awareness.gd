extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var sim=Sim.new(31,"cave",1);sim.enemies.clear();sim.map.floor_cells.clear()
	for x in range(1,21):
		for y in range(1,21):
			if x!=8 or y==6:sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"탐사");p.pos=Vector2(6,10)
	var enemy=sim.spawn_enemy("rat",Vector2(10,10),1)
	check(sim.awareness.emit(1,p.pos,8)==0,"quiet attack cannot alert through solid wall")
	sim.clock=1.
	check(sim.awareness.emit(1,p.pos,12)==1,"heavy sound reaches through actual corridor")
	check(enemy.search_path.all(func(pos):return sim.map.walkable(pos)),"investigation path stays on floor")
	check(enemy.search_path.has(Vector2(8,6)),"investigation follows opening instead of clipping wall")
	for i in range(5):sim.awareness.investigate(enemy,3.,.1)
	var before=enemy.pos
	check(sim.awareness.investigate(enemy,3.,.1) and enemy.pos!=before,"heard sound changes movement")
	sim.clock=10.
	check(sim.awareness.investigate(enemy,3.,.1) and enemy.awareness_state=="return","expired investigation returns home")
	for i in range(200):sim.awareness.investigate(enemy,3.,.1)
	check(enemy.pos.distance_to(enemy.home)<.3,"return route does not stall at corner")
	sim.clock=20.;enemy.guardian=true
	check(sim.awareness.emit(1,p.pos,12)==0,"guardian stays with exit")
	enemy.guardian=false;p.network_leaving=true;sim.clock=30.
	check(sim.awareness.emit(1,p.pos,12)==0,"departing owner cannot lure")
	p.network_leaving=false;sim.map.floor_number=10;sim.map.raid_arena=true
	check(sim.awareness.emit(1,p.pos,12)==0,"raid pattern remains authoritative")

	sim.map.raid_arena=false;sim.map.floor_number=1;sim.clock=40.;p.invulnerable=100.;p.pos=Vector2(6,10)
	for attempt in [["attack",Vector2(10,6)],["heavy",Vector2(10,10)],["skill_q",Vector2(10,8)]]:
		sim.enemies.clear();enemy=sim.spawn_enemy("rat",attempt[1],1);sim.clock+=1.
		p.pos=Vector2(6,10);p.attack_cd=0.;p.charge_time=-1.;p.stamina=p.max_stamina;p.sprint=true;p.dir=Vector2.DOWN;p.input_age=0.
		sim.tick(.02);p.sprint=false;p.dir=Vector2.ZERO
		check(enemy.get("awareness_state","")=="", "sprint sound remains shorter than attack")
		if attempt[0]=="heavy":check(sim.action(1,"heavy_begin"),"begin charge");p.charge_time=.9
		if attempt[0]=="skill_q":
			var node=sim.Content.SKILLS[p.class_id].filter(func(n):return n.effect=="active")[0]
			p.skill_ranks[node.id]=1;p.skill_loadout.skill_q=node.id;p.skill_cooldowns.clear()
		check(sim.action(1,attempt[0]),"successful loud action after sprint "+attempt[0])
		check(enemy.get("awareness_state","")=="search","louder same-frame action not suppressed "+attempt[0])
	sim.enemies.clear();enemy=sim.spawn_enemy("rat",Vector2(10,10),1);sim.clock=60.;p.pos=Vector2(6,10);p.dir=Vector2.ZERO;p.sprint=false
	sim.awareness.emit(1,p.pos,12)
	var engaged=false
	for i in range(160):
		p.invulnerable=100.;sim.tick(.05)
		if enemy.get("awareness_state","")=="engaged" and enemy.pos.x<8:engaged=true;break
	check(engaged,"actual tick changes investigation to engagement around corner")
	p.pos=Vector2(19,19)
	for i in range(240):sim.tick(.05)
	check(enemy.pos.distance_to(enemy.home)<.3,"lost target returns through opening after engagement")
	print("ENEMY_AWARENESS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
