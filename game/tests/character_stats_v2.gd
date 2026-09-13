extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const P=preload("res://scripts/progression.gd")
const Spec=preload("res://scripts/stat_specialization.gd")
const Content=preload("res://scripts/content.gd")
const Creation=preload("res://scripts/character_creation.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Local=preload("res://scripts/local_session.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func close(a:float,b:float)->bool:return absf(a-b)<.0001
func runtime_hooks():
	var sim=Sim.new(7732,"forest",1);sim.enemies.clear()
	var p=sim.add_player(1,"실제 효과");p.level=60;p.class_id="hunter";sim.combat.jobs.reset(p)
	p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT
	var e=sim.spawn_enemy("shade",p.pos+Vector2(1,0),0,false);e.hp=100000;e.max_hp=e.hp
	var jobs=sim.combat.jobs
	jobs.status(p,e,"bleed",4.);jobs.tick(p,1.01);var normal_dot=100000-e.hp
	e.hp=100000;e.job_status={};p.stats.specialization=60;jobs.status(p,e,"bleed",4.);jobs.tick(p,1.01)
	check(100000-e.hp>normal_dot,"hunter specialization increases actual periodic hit")
	p.class_id="thief";jobs.reset(p);jobs.status(p,e,"vulnerable",4.)
	check(close(e.job_status.vulnerable.value,.21),"thief status snapshots source specialization")
	p.stats.specialization=0;p.job_state.buffs.clear()
	check(jobs.outgoing(p,e,1000)==1210,"stored vulnerability survives source stat change")
	p.class_id="explorer";p.stats.specialization=60;jobs.reset(p);e.stun_time=0;sys_clear(e)
	jobs.status(p,e,"stun",3.)
	check(close(e.stun_time,1.575) and close(e.job_status.stun.time,3.15),"explorer actual control duration and hard CC cap both scale")
	p.class_id="infighter";jobs.reset(p);sys_clear(e);p.job_state.rush=0
	var idle=jobs.outgoing(p,e,1000);p.job_state.rush=10
	check(jobs.outgoing(p,e,1000)==1100 and idle==1000,"infighter actual outgoing damage requires maintained stacks")
	for job in ["reaper","breaker"]:
		p.class_id=job;jobs.reset(p);p.stats.specialization=0;var ordinary=jobs.attack_multiplier(p,true)
		p.stats.specialization=60;check(close(jobs.attack_multiplier(p,true)/ordinary,1.125),"actual basic heavy specialization "+job)
	p.class_id="warrior";jobs.reset(p);p.stats.precision=60;sys_clear(e);e.hp=100000
	jobs.buff(p,"crit",1.,5.);jobs.buff(p,"crit_damage",.5,5.)
	var crit=preload("res://scripts/combat_stats.gd").critical(p,jobs)
	sim.rng.seed=713;var roll=sim.rng.randf();sim.rng.seed=713
	check(sim.combat.hit(p,e,1000) and 100000-e.hp==(roundi(1000*crit.maximum) if roll<crit.chance else 1000),"actual hit uses shared critical chance and one multiplier")
	p.class_id="healer";p.stats.precision=0;p.stats.specialization=0;jobs.reset(p)
	var ally=sim.add_player(2,"회복 대상");ally.pos=p.pos;ally.stats.vitality=60;sim.recalculate(ally);ally.hp=1
	var heal=Content.SKILLS.healer.filter(func(node):return node.effect=="active" and node.mode=="heal")[0]
	p.skill_ranks={heal.id:1};p.skill_loadout={"skill_q":heal.id};p.skill_cooldowns={};p.stamina=10000;p.max_stamina=10000
	var cast=Balance.profile(p,heal,1,sim.damage_for(p),p.max_hp)
	var expected=mini(ally.max_hp-1,roundi(cast.heal*float(ally.max_hp)/p.max_hp*P.received_healing(ally)))
	check(sim.action(1,"skill_q"),"real healer action accepted")
	for i in range(100):sim.clock+=.02;jobs.tick(p,.02)
	check(ally.hp==1+expected,"recipient vitality applies to actual skill heal exactly once")
func sys_clear(enemy:Dictionary):enemy.job_status={};enemy.erase("constellation_marks")
func run():
	Content.initialize_jobs()
	var sim=Sim.new(6602,"town");var p=sim.add_player(1,"여섯 능력치");p.level=100;p.creation_points=10
	var before=sim.damage_for(p,"physical");p.stats.power=60;sim.recalculate(p)
	check(sim.damage_for(p,"physical")==before+120 and sim.damage_for(p,"magic")==before+120,"power changes both actual damage channels")
	var hp=p.max_hp;p.stats.vitality=60;sim.recalculate(p)
	check(p.max_hp==hp+480 and close(P.received_healing(p),1.075),"vitality health and skill healing")
	p.stats.fortitude=60;sim.recalculate(p)
	check(p.defense==120 and p.magic_defense==120 and close(P.hurt_duration_factor(p),.9),"fortitude defenses and ordinary hurt duration")
	p.stats.swiftness=60
	check(close(P.attack_speed(p),1.2) and close(P.move_speed(p),1.1) and close(P.cast_speed(p),1.125),"swiftness independent speed curves")
	check(close(P.cast_time(p,2.),2./1.125) and P.cast_time(p,0)==0 and P.cast_time(p,.01)==.1 and P.cast_time(p,2.,true)==2.,"windup speed preserves instant and charge timing")
	p.stats.precision=60
	check(close(P.critical_chance(p,.1),.175) and close(P.critical_multiplier(p,1.5),1.65),"precision chance and multiplier")
	check(P.critical_chance(p,2.)==.85 and P.critical_multiplier(p,8.)==3.,"critical final caps")
	check(P.cooldown_factor(p)==1.,"removed technique does not grant universal cooldown reduction")
	for version in [5,6,7]:
		var old={"schema_version":version,"level":20,"creation_points":10 if version==7 else 0,"stats":{"strength":11,"magic":9} if version>=6 else {"strength":11,"intelligence":9}}
		P.migrate(old);P.initialize(old)
		check(P.available(old)==57+(10 if version==7 else 0) and old.stat_schema_version==2,"old investments refunded within preserved budget "+str(version))
		old.stats.power=7;var snapshot=old.duplicate(true);P.migrate(old)
		check(old==snapshot and old.stat_migration.old_stats.strength==11,"second migration preserves new investment and audit "+str(version))
	check(P.gear_values({"strength":3,"magic":7,"endurance":4})=={"power":7,"fortitude":4},"legacy per-item strength and magic use maximum")
	var item=Equipment.make("sword",0,1,"legacy-id","fortune","warrior");item.upgrade=2
	p.class_id="warrior";p.inventory=[item];p.equipment={"weapon":"legacy-id"};p.equipped="legacy-id";sim.recalculate(p)
	check(p.gear_stats.get("power",0)==3 and p.inventory[0].id=="legacy-id" and p.inventory[0].affix=="fortune","old affix ID gives new stat without item replacement")
	var saved=sim.persistent(1);saved.world_seed=6602
	var local=Local.new();var parsed=local.validate_save(saved.duplicate(true))
	check(parsed!=null and parsed.stat_schema_version==2,"new save schema accepted")
	var bad=saved.duplicate(true);bad.stats.strength=1
	check(local.validate_save(bad)==null,"new schema rejects old investment keys")
	bad=saved.duplicate(true);bad.stat_schema_version=3
	check(local.validate_save(bad)==null,"unknown stat schema rejected")
	var old_save=saved.duplicate(true);old_save.erase("stat_schema_version");old_save.stats={"strength":11,"magic":9};old_save.creation_points=10
	parsed=local.validate_save(old_save)
	check(parsed!=null and parsed.stats.is_empty() and parsed.inventory==saved.inventory,"validated legacy save refunds investments and preserves item bytes")
	var restored=Sim.new(6602,"town");var r=restored.add_player(1,"",parsed)
	check(P.available(r)==307 and r.gear_stats.power==3 and r.inventory[0].id=="legacy-id","restored budget and old gear work together")
	r.stats.power=7;var persisted=restored.persistent(1);persisted.world_seed=6602
	parsed=local.validate_save(persisted);var again=Sim.new(6602,"town");var a=again.add_player(1,"",parsed)
	check(a.stats.power==7 and P.available(a)==300,"persistent marker prevents second refund")
	local.free()
	for cls in Creation.CLASSES:
		var sheet={"name":"검사","class_id":cls,"avatar":"auto","costume":"none","stats":Creation.suggested(cls)}
		check(Creation.reason(sheet).is_empty() and sheet.stats.size()==6 and Creation.player_data(sheet).stat_schema_version==2,"creation preset matches six stats "+cls)
	var covered=[]
	for cls in Content.CLASSES:
		var low={"class_id":cls,"stats":{},"gear_stats":{},"skill_ranks":{},"level":60,"job_state":{"rush":10}}
		var high=low.duplicate(true);high.stats.specialization=60
		var changed=false
		for node in Content.SKILLS[cls]:
			if node.effect!="active":continue
			var before_profile={};var after_profile={}
			if cls in ["warrior","ranger","mage"]:
				before_profile=Scaling.profile(node,1,{"player":low});after_profile=Scaling.profile(node,1,{"player":high})
			else:
				before_profile=Balance.profile(low,node,1,100,1000);after_profile=Balance.profile(high,node,1,100,1000)
			for key in ["power","multiplier","heal","regen","shield","pet_power","pet_hp","counter_power","buff"]:
				if float(after_profile.get(key,0))>float(before_profile.get(key,0)):changed=true
		match cls:
			"tank":changed=Spec.stagger_factor(high)>Spec.stagger_factor(low)
			"hunter":changed=Spec.periodic_factor(high,"bleed")>1. and Spec.execute_factor(high,{"mode":"execute_shot"},{"job_status":{"bleed":{}}})>1.
			"explorer":changed=Spec.control_duration(high,{},"stun",.5)>.5 and Spec.control_duration(high,{"boss":true},"stun",.5)==.5
			"thief":changed=Spec.debuff_value(high,"vulnerable",.2)>.2 and Spec.debuff_value(high,"weaken",.2)==.2
			"infighter":changed=Spec.rush_factor(high)>1.
		check(changed and Spec.RULES.has(cls),"concrete specialization mapping "+cls);covered.append(cls)
	check(covered.size()==20,"all twenty current classes covered")
	var no_rush={"class_id":"infighter","stats":{"specialization":60},"job_state":{"rush":0}}
	check(Spec.rush_factor(no_rush)==1.,"rush specialization needs current stacks")
	var hunter={"class_id":"hunter","stats":{"specialization":60}}
	check(Spec.execute_factor(hunter,{"mode":"execute_shot"},{})==1.,"execute specialization needs bleeding target")
	var base_profile={"power":2.,"heal":0.,"regen":0.,"shield":0.,"pet_power":0.,"pet_hp":0.,"counter_power":0.,"buff":0.}
	check(Spec.apply_job({"class_id":"gambler","stats":{"specialization":60}},{"mode":"settle","ultimate":true},base_profile.duplicate())==base_profile,"ultimate excluded from profile specialization")
	runtime_hooks()
	print("CHARACTER_STATS_V2 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
