extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Conditions=preload("res://scripts/skill_conditions.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture(job:String,skill:String):
	var sim=Sim.new(941,"cave",12);sim.enemies.clear();sim.map.floor_cells.clear();sim.map.spawn=Vector2.ONE
	for x in range(1,35):
		for y in range(1,25):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"공략");p.class_id=job;p.level=20;p.skill_ranks={skill:1};p.skill_loadout={"skill_q":skill};p.pos=Vector2(10,10);p.aim=Vector2.RIGHT
	sim.combat.jobs.reset(p);sim.recalculate(p);p.invulnerable=10000.;p.hp=p.max_hp
	var enemy=sim.spawn_enemy("rat",Vector2(14,10),20);enemy.hp=1000000;enemy.max_hp=1000000;enemy.cooldown=10000.;enemy.speed=0.
	return sim
func _initialize():
	Content.initialize_jobs()
	for skill in ["elementalist_a02","elementalist_a03"]:
		for reason in ["range","wall","dead","clear","empty"]:
			var sim=fixture("elementalist",skill);var p=sim.players[1];var enemy=sim.enemies[1]
			if reason=="empty":sim.enemies.clear()
			var before=p.stamina
			check(sim.action(1,"skill_q"),"real cast accepted "+skill+reason)
			check(not p.job_state.casting.is_empty() and p.stamina<before,"windup pays resource")
			var paid=p.stamina;var cooldown=p.skill_cooldowns[skill]
			if reason=="range":enemy.pos=Vector2(30,10)
			if reason=="wall":
				for y in range(1,25):sim.map.floor_cells.erase(Vector2i(12,y))
			if reason=="dead":enemy.hp=0
			# Tick the real job scheduler without AI movement or stamina regeneration.
			sim.combat.jobs.tick(p,1.2)
			var blocked=reason in ["range","wall","dead"]
			check(p.job_state.casting.is_empty(),"windup finished")
			check(p.stamina==paid and p.skill_cooldowns[skill]==cooldown,"no free cancellation refund")
			if blocked:
				check(sim.combat.skills.zones.is_empty() and enemy.hp== (0 if reason=="dead" else enemy.max_hp),"no damage or remote zone after lost target")
				check(sim.events.any(func(e):return e.type=="notice" and e.owner==1),"owner receives rejection")
			elif reason=="clear":check(not sim.combat.skills.zones.is_empty() if skill=="elementalist_a02" else enemy.hp<enemy.max_hp,"valid target still works")
			elif reason=="empty":check(not sim.events.any(func(e):return e.type=="notice"),"empty ground remains valid")
	for front in [true,false]:
		var sim=fixture("reaper","reaper_a05");var p=sim.players[1];var enemy=sim.enemies[1]
		sim.combat.jobs.buff(p,"guard",.35,5.)
		check(sim.action(1,"skill_q"),"guarded heavy starts")
		var paid=p.stamina;var cooldown=p.skill_cooldowns.reaper_a05
		enemy.pos=p.pos+Vector2(2 if front else -2,0)
		var amount=sim.combat.jobs.receive(p,enemy,100,true)
		check(amount== (65 if front else 100),"front damage protection only")
		check(p.job_state.casting.is_empty()!=front,"rear hit interrupts protected cast")
		check(p.stamina==paid and p.skill_cooldowns.reaper_a05==cooldown,"interrupt keeps paid cost")
	for rank in range(6):
		var sim=fixture("sniper","sniper_a01");var p=sim.players[1];p.skill_ranks.sniper_p05=rank
		var node=Content.active_node(p,"skill_q");var cast=Balance.profile(p,node,1,100,p.max_hp)
		var rows=Balance.metrics(p,node,1,100,p.max_hp)
		check(is_equal_approx(Conditions.casting_speed(p),.2+.04*rank),"sniper mobility passive")
		check(rows.any(func(row):return row[0]=="시전 중 이동" and row[1]=="%.0f%%"%(Conditions.casting_speed(p)*100.)),"runtime and display same mobility")
	for legal in [true,false]:
		var sim=fixture("reaper","reaper_a01");var p=sim.players[1];var enemy=sim.enemies[1]
		var node=Content.active_node(p,"skill_q");var cast=Balance.profile(p,node,1,100,p.max_hp)
		enemy.pos=p.pos+Vector2(cast.node.range+preload("res://scripts/enemy_hit_geometry.gd").radius(enemy)+( -.01 if legal else .01),0)
		var before=p.stamina
		check(sim.action(1,"skill_q")==legal,"chain uses body edge boundary")
		check(p.stamina<before if legal else p.stamina==before,"invalid initial target spends nothing")
	var sim=fixture("elementalist","elementalist_a02");var p=sim.players[1]
	check(sim.action(1,"skill_q"),"cancel fixture starts real cast")
	var paid=p.stamina;var cooldown=p.skill_cooldowns.elementalist_a02
	check(sim.action(1,"cancel_charge") and p.job_state.casting.is_empty(),"explicit cancel clears real cast")
	check(p.stamina==paid and p.skill_cooldowns.elementalist_a02==cooldown,"explicit cancellation does not refund")
	print("SKILL_CONDITIONS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
