extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures=[]
class WallArena extends RefCounted:
	func walkable(at:Vector2)->bool:return at.x<3.
	func in_town(_at:Vector2)->bool:return false
	func line_clear(_from:Vector2,_to:Vector2)->bool:return true
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	for floor_id in [10,20,30,100]:
		var sim=Sim.new(177,"cave",floor_id);var p=sim.add_player(1,"원거리 교전")
		var boss=sim.enemies.values().filter(func(e):return e.get("raid",false))[0]
		for e in sim.enemies.values():
			if e!=boss:e.hp=0
		var candidates=sim.map.floor_cells.keys().filter(func(cell):return Vector2(cell).distance_to(boss.home)>10. and Vector2(cell).distance_to(boss.home)<13. and sim.map.line_clear(Vector2(cell),boss.home))
		check(not candidates.is_empty(),"actual raid has outer approach B"+str(floor_id))
		if candidates.is_empty():continue
		p.pos=Vector2(candidates[0]);p.invulnerable=100.;boss.hp=boss.max_hp*.9;boss.stagger.engaged=true
		var damaged=boss.hp;var generation=boss.stagger.generation
		for step in range(80):
			sim.tick(.1)
			if step%10==0:Stagger.apply(sim,p,boss,Stagger.context(Stagger.basic_token(false,0,sim.clock)))
		check(boss.hp==damaged and boss.stagger.generation==generation,"outer 10-13 range combat does not reset after eight seconds B"+str(floor_id))
		p.pos=sim.map.spawn
		for step in range(60):sim.tick(.1)
		check(boss.hp==boss.max_hp and boss.stagger.generation>generation,"actual departure resets boss B"+str(floor_id))
		check(is_equal_approx(boss.stagger.max_value,(180.+floor_id*.8)*2.5),"normal break requirement increased 2.5 times")
	var node={"effect":"active","mode":"wave","max_rank":3}
	var attack=Stagger.skill_profile(node,1,{"class_id":"breaker"})
	var support=Stagger.skill_profile(node,1,{"class_id":"healer"})
	check(support.value>attack.value and support.class_multiplier<=1.65,"low damage role has bounded stagger advantage")
	node.mode="heal"
	check(Stagger.skill_profile(node,1,{"class_id":"healer"}).value==0,"non-hitting heal cannot create boss damage")
	wall_contract()
	print("RAID_ENGAGEMENT checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)

func charge(sim,boss):
	boss.pos=Vector2.ZERO;boss.pattern=3
	sim.monster_attacks.begin(boss,Vector2.RIGHT);sim.monster_attacks.release(boss)

func wall_contract():
	var sim=Sim.new(27,"cave",10);sim.enemies.clear()
	var p=sim.add_player(1,"벽 유도 검사");p.pos=Vector2(2,1);p.invulnerable=100.
	var boss=sim.spawn_enemy("warden",Vector2.ZERO,10,true);boss.raid=true;sim.map=WallArena.new()
	charge(sim,boss)
	check(boss.pos.x<3. and boss.stagger.state=="down" and boss.stagger.breaks==1,"ready wall impact creates exactly one stagger")
	var before=JSON.stringify(boss.stagger);var event_count=sim.events.size()
	check(not Stagger.break_boss(sim,boss) and before==JSON.stringify(boss.stagger) and event_count==sim.events.size(),"down reentry cannot extend timer or duplicate effects")
	Stagger.tick(sim,boss,Stagger.DOWN_SECONDS)
	for elapsed in [0.,59.]:
		if elapsed>0:Stagger.tick(sim,boss,elapsed)
		before=JSON.stringify(boss.stagger)
		charge(sim,boss)
		check(before==JSON.stringify(boss.stagger) and boss.pos.x<3. and boss.cooldown>=1.,"wall stops without bypassing successful lock at "+str(elapsed))
		check(not boss.has("wall_charge") and not boss.has("attack_areas"),"wall flags always cleaned")
	Stagger.tick(sim,boss,1.);charge(sim,boss)
	check(boss.stagger.state=="down" and boss.stagger.breaks==2,"wall stagger works after sixty-second lock expires")
	Stagger.initialize(boss);boss.pos=Vector2.ZERO;boss.pattern=3
	sim.monster_attacks.begin(boss,Vector2.RIGHT);Stagger.start_check(sim,boss,0)
	check(not boss.has("wall_charge"),"HP check interrupts and clears pending charge")
	Stagger.tick(sim,boss,Stagger.CHECK_SECONDS)
	check(boss.stagger.state=="immune" and boss.stagger.time_left==6. and not boss.has("wall_charge") and boss.attack_areas[0].shape=="circle","failed check retains circular punishment and separate six-second lock")
	before=JSON.stringify(boss.stagger);charge(sim,boss)
	check(before==JSON.stringify(boss.stagger),"wall also respects failed-check immunity")
	# A real parry counter can fill the meter during impact before the wall branch.
	Stagger.initialize(boss);boss.stagger.max_value=1.;sim.events.clear()
	p.pos=Vector2(2.3,0);p.aim=Vector2.RIGHT;p.invulnerable=0.;p.job_state.parry=1.;p.job_state.parry_kind="parry_counter"
	p.job_state.parry_stagger=Stagger.context(Stagger.basic_token(true,1.,sim.clock))
	charge(sim,boss)
	check(p.job_state.parry==0. and boss.stagger.breaks==1 and sim.events.filter(func(event):return event.type=="stagger_break").size()==1,"counter followed by wall branch cannot double-break")
	check(not Stagger.break_boss(sim,{"boss":false,"hp":100}) and not Stagger.break_boss(sim,{"boss":true,"hp":0}) and not Stagger.break_boss(sim,{"boss":true,"hp":100}),"invalid or dead boss rejected safely")
