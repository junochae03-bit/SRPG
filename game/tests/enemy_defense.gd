extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Guard=preload("res://scripts/enemy_defense.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var sim=Sim.new(381,"cave",1)
	var enemy=sim.spawn_enemy("beetle",sim.map.spawn+Vector2(5,0),1)
	var basic=Stagger.context(Stagger.basic_token(false,0.,0.))
	check(Guard.factor(sim,enemy,basic)==.75,"intact guard mitigates")
	var pressure=enemy.guard_pressure
	for i in range(10):Guard.factor(sim,enemy,basic)
	check(enemy.guard_pressure==pressure,"same cast cannot duplicate guard pressure")
	for i in range(5):Guard.factor(sim,enemy,Stagger.context(Stagger.basic_token(false,0.,0.)))
	check(enemy.guard_break_time==4. and Guard.factor(sim,enemy,{})==1.,"successive basic attacks break guard")
	enemy.guard_break_time=0.;enemy.guard_pressure=0.
	Guard.factor(sim,enemy,Stagger.context(Stagger.basic_token(true,1.,0.)))
	check(Guard.factor(sim,enemy,Stagger.context(Stagger.basic_token(true,1.,0.)))==1.,"two full heavy attacks break guard faster")
	enemy.guard_break_time=0.;enemy.guard_pressure=0.;enemy.boss=true
	check(Guard.factor(sim,enemy,Stagger.context(Stagger.basic_token(true,1.,0.)))==.75 and enemy.guard_pressure==0.,"boss keeps dedicated stagger rules")
	enemy.boss=false;enemy.guard_pressure=30.;enemy.guard_last_hit=0.;sim.clock=5.
	Guard.factor(sim,enemy,Stagger.context(Stagger.basic_token(false,0.,5.)))
	check(enemy.guard_pressure==7.,"pressure expires outside sustained assault")

	sim.enemies.clear();sim.map.floor_cells.clear();sim.map.spawn=Vector2(1,1)
	for x in range(1,20):
		for y in range(1,20):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"방어 공략");p.pos=Vector2(10,10);p.skill_ranks={}
	enemy=sim.spawn_enemy("beetle",Vector2(11,10),1);enemy.hp=10000;enemy.max_hp=10000
	var old=enemy.hp
	check(sim.combat.hit(p,enemy,100,null,Stagger.context(Stagger.basic_token(true,1.,sim.clock))),"actual charged hit accepted")
	var protected=old-enemy.hp
	enemy.windup=1.;enemy.attack_areas=[{}];sim.monster_attacks.zones=[{"enemy":enemy.id}];old=enemy.hp
	check(sim.combat.hit(p,enemy,100,null,Stagger.context(Stagger.basic_token(true,1.,sim.clock))),"second charged hit accepted")
	check(old-enemy.hp>protected and enemy.guard_break_time==4.,"guard break increases actual damage")
	check(enemy.windup==0. and not enemy.has("attack_areas") and sim.monster_attacks.zones.is_empty(),"guard break cancels windup and delayed attacks")
	print("ENEMY_DEFENSE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
