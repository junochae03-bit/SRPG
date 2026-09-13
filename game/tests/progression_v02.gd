extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const P=preload("res://scripts/progression.gd")
const C=preload("res://scripts/content.gd")
const B=preload("res://scripts/job_balance.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var sim=Sim.new(987);var p=sim.add_player(1,"성장 검증");p.level=60;sim.recalculate(p)
	check(p.stats.keys()==P.NAMES.keys() and p.stats.size()==6,"six exact stat keys")
	var physical=sim.damage_for(p,"physical");var magical=sim.damage_for(p,"magic");var hp=p.max_hp
	check(sim.action(1,"stat","power"),"spend power")
	check(sim.damage_for(p,"physical")==physical+2 and sim.damage_for(p,"magic")==magical+2,"power increases both damage channels")
	sim.action(1,"stat","vitality")
	check(p.max_hp==hp+8,"vitality increases actual health")
	var before=P.received(p,100);sim.action(1,"stat","fortitude")
	check(p.defense==2 and p.magic_defense==2 and p.max_hp==hp+8,"fortitude increases both defenses only")
	p.stats.fortitude=50;sim.recalculate(p)
	check(P.received(p,100)<before and P.received(p,100,true)==P.received(p,100),"both damage channels mitigate")
	p.class_id="swordsman";sim.combat.jobs.reset(p);p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT
	var n=C.SKILLS.swordsman.filter(func(x):return x.effect=="active")[0]
	var initial=B.profile(p,n,1,sim.damage_for(p),p.max_hp)
	p.stats.specialization=60
	var reduced=B.profile(p,n,1,sim.damage_for(p),p.max_hp)
	check(is_equal_approx(reduced.cooldown,initial.cooldown),"specialization does not grant generic cooldown reduction")
	p.skill_ranks[n.id]=1;p.skill_loadout.skill_q=n.id
	check(sim.action(1,"skill_q") and is_equal_approx(p.skill_cooldowns[n.id],reduced.cooldown),"actual cast uses reduced cooldown")
	p.job_state.casting={};p.attack_cd=0;sim.combat.attack(p,false,0);var old_cd=p.attack_cd
	p.stats.swiftness=60;p.attack_cd=0;sim.combat.attack(p,false,0)
	check(p.attack_cd<old_cd and P.move_speed(p)>1.,"swiftness actual attack speed and movement")
	for points in range(0,1001,10):
		p.stats.specialization=points;p.stats.swiftness=points;p.stats.fortitude=points;sim.recalculate(p)
		check(P.cooldown_factor(p)==1. and P.attack_speed(p)<1.4 and P.move_speed(p)<1.2 and P.cast_speed(p)<1.25 and P.mitigation(p)<=.7,"bounded stats "+str(points))
	var legacy={"schema_version":5,"level":60,"stats":{"strength":70,"dexterity":30,"intelligence":0,"vitality":77}}
	P.migrate(legacy);P.initialize(legacy)
	check(P.available(legacy)==177 and legacy.stats.keys()==P.NAMES.keys(),"legacy fully refunded")
	var fresh={"schema_version":7,"stat_schema_version":2,"level":10,"stats":{"power":5,"specialization":10,"precision":12}}
	P.migrate(fresh);P.initialize(fresh);check(P.available(fresh)==0 and fresh.stats.specialization==10,"versioned six-stat saves retain allocation")
	print("PROGRESSION_V02_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
