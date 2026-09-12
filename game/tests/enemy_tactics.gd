extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Tactics=preload("res://scripts/enemy_tactics.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var sim=Sim.new(742,"cave",12);sim.enemies.clear();sim.map.floor_cells.clear()
	for x in range(1,25):
		for y in range(1,25):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"장판");p.pos=Vector2(8,8)
	var e=sim.spawn_enemy("goblin_archer",Vector2(11,8),1)
	sim.combat.skills.zones=[{"owner":1,"amount":10,"pulses":[1.,2.,3.],"radius":3.,"pos":Vector2(10,8)}]
	var old=e.pos
	check(not Tactics.avoid(sim,e,2.,.1) and e.pos==old,"reaction delay prevents instant dodge")
	sim.clock=1.;var before=Tactics.danger(sim,e,e.pos)
	check(Tactics.avoid(sim,e,2.,.1) and Tactics.danger(sim,e,e.pos)<before,"intelligent ranged enemy escapes damaging ground")
	sim.combat.skills.zones[0].mode="trap"
	check(not Tactics.avoid(sim,e,2.,.1),"concealed traps cannot be predicted")
	sim.combat.skills.zones[0].erase("mode");e.raid=true
	check(not Tactics.avoid(sim,e,2.,.1),"raid pattern never overridden")
	e.raid=false;e.taunt_time=2.
	check(not Tactics.avoid(sim,e,2.,.1),"taunt holds intelligent target in allied attack area")
	e.taunt_time=0.;e.kind="rat"
	check(not Tactics.avoid(sim,e,2.,.1),"beasts retain direct pressure")
	var ally=sim.spawn_enemy("rat",e.pos+Vector2(.3,0),1);old=e.pos
	Tactics.spread(sim,e,2.,.1)
	check(e.pos.distance_to(ally.pos)>old.distance_to(ally.pos),"pack separates without teleporting")
	check(e.pos.distance_to(old)<=.071,"separation respects walking speed")
	e.windup=1.;old=e.pos;Tactics.spread(sim,e,2.,.1)
	check(e.pos==old,"committed attack keeps telegraph origin")

	e.windup=0.;e.kind="goblin_archer";e.pos=Vector2(11,8);sim.map.spawn=Vector2(1,1)
	p.network_leaving=true
	check(Tactics.danger(sim,e,e.pos)==0. and not sim.combat.hit(p,e,100),"departing owner's inert zone neither damages nor scares enemies")
	p.network_leaving=false;sim.enemies.erase(ally.id);e.hp=10000.;e.max_hp=10000.;e.taunt_time=3.;e.taunt_owner=1;e.hazard_since=0.;sim.clock=2.
	sim.combat.skills.zones[0].merge({"elapsed":0.,"pulses":[100.],"slow":0.,"stun":0.})
	old=e.pos;sim.tick(.05)
	check(e.windup>0 and e.pos==old,"actual tick commits attack under taunt instead of evading ground")
	print("ENEMY_TACTICS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
