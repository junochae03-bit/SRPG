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
	check(p.stats.keys()==P.NAMES.keys(),"five exact stat keys")
	var physical=sim.damage_for(p,"physical");var magical=sim.damage_for(p,"magic");var hp=p.max_hp
	check(sim.action(1,"stat","strength"),"spend strength")
	check(sim.damage_for(p,"physical")==physical+2 and sim.damage_for(p,"magic")==magical,"strength only physical")
	sim.action(1,"stat","magic")
	check(sim.damage_for(p,"magic")==magical+2 and sim.damage_for(p,"physical")==physical+2,"magic only magical")
	var before=P.received(p,100);sim.action(1,"stat","endurance")
	check(p.defense==2 and p.magic_defense==2 and p.max_hp==hp,"endurance both defense, HP level growth")
	p.stats.endurance=50;sim.recalculate(p)
	check(P.received(p,100)<before and P.received(p,100,true)==P.received(p,100),"both damage channels mitigate")
	p.class_id="swordsman";sim.combat.jobs.reset(p);p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT
	var n=C.SKILLS.swordsman.filter(func(x):return x.effect=="active")[0]
	var initial=B.profile(p,n,1,sim.damage_for(p),p.max_hp)
	p.stats.technique=60
	var reduced=B.profile(p,n,1,sim.damage_for(p),p.max_hp)
	check(is_equal_approx(reduced.cooldown,initial.cooldown*.8),"technique runtime profile 20 percent at 60")
	p.skill_ranks[n.id]=1;p.skill_loadout.skill_q=n.id
	check(sim.action(1,"skill_q") and is_equal_approx(p.skill_cooldowns[n.id],reduced.cooldown),"actual cast uses reduced cooldown")
	p.job_state.casting={};p.attack_cd=0;sim.combat.attack(p,false,0);var old_cd=p.attack_cd
	p.stats.agility=60;p.attack_cd=0;sim.combat.attack(p,false,0)
	check(p.attack_cd<old_cd and P.move_speed(p)>1.,"agility actual attack speed and movement")
	for points in range(0,1001,10):
		p.stats.technique=points;p.stats.agility=points;p.stats.endurance=points;sim.recalculate(p)
		check(P.cooldown_factor(p)>.59 and P.attack_speed(p)<1.65 and P.move_speed(p)<1.3 and P.mitigation(p)<=.7,"bounded stats "+str(points))
	var legacy={"schema_version":5,"level":60,"stats":{"strength":70,"dexterity":30,"intelligence":0,"vitality":77}}
	P.migrate(legacy);P.initialize(legacy)
	check(P.available(legacy)==177 and legacy.stats.keys()==P.NAMES.keys(),"legacy fully refunded")
	var fresh={"schema_version":6,"level":10,"stats":{"strength":5,"technique":10,"magic":12}}
	P.migrate(fresh);P.initialize(fresh);check(P.available(fresh)==0 and fresh.stats.technique==10,"new saves retain allocation")
	print("PROGRESSION_V02_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
