extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func prime(sim,p):
	p.constellation_state.last_skill="blade";p.constellation_state.last_time=4.;p.constellation_state.move_time=3.;p.constellation_state.support_time=5.
	sim.combat.jobs.buff(p,"attack",.2,8.);p.job_state.shield=50.;p.job_state.shield_time=8.
	p.barrier_time=8.;p.haste_time=8.;p.charge_time=.5;p.dodge_time=.2;p.invulnerable=.4;p.motion="cast_high";p.motion_time=2.
	p.skill_cooldowns["test_skill"]=9.;p.potion_cd=4.
	sim.combat.launch(p,"staff",Vector2.RIGHT,10,8,9,0)
	sim.combat.skills.add_zone(p,"star_impact",p.pos,2,10,[9.])
	# Queue is an actual deferred combat event; the long delay keeps ownership assertions deterministic.
	sim.combat.constellation.pending.append({"owner":p.id,"time":9.,"context":{},"kind":"burn","target":1,"pos":p.pos,"amount":10,"radius":2.,"origin":p.pos,"aim":p.aim})
func _initialize():
	Content.initialize_jobs()
	for job in Content.CLASSES:
		var sim=Sim.new(931,"cave",12);sim.enemies.clear()
		var p=sim.add_player(1,"검증");var ally=sim.add_player(2,"동료")
		p.class_id=job;p.level=30;sim.combat.jobs.reset(p);sim.recalculate(p)
		prime(sim,p);prime(sim,ally)
		var enemy=sim.spawn_enemy("rat",p.pos+Vector2(3,0),12);enemy.cooldown=100.;enemy.speed=0.
		sim.combat.jobs.status(p,enemy,"bleed",8.);sim.combat.jobs.status(ally,enemy,"weaken",8.)
		enemy.constellation_marks={"1":{"time":8.},"2":{"time":8.}};enemy.taunt_owner=1;enemy.taunt_time=8.
		var ally_state=ally.duplicate(true);var gold=p.gold
		sim.player_defeated(p)
		check(p.hp==0 and p.down_time>0,job+" downed")
		check(p.constellation_state.last_time==0 and p.constellation_state.move_time==0 and p.constellation_state.support_time==0,job+" no frozen followup window")
		check(p.job_state.buffs.is_empty() and p.job_state.shield==0 and p.barrier_time==0 and p.haste_time==0,job+" temporary protection cleared")
		check(p.charge_time<0 and p.dodge_time==0 and p.invulnerable==0 and p.motion_time==0,job+" cast and motion cleared")
		check(p.skill_cooldowns.test_skill==9. and p.potion_cd==4.,job+" defeat never refunds cooldown")
		check(ally==ally_state,job+" other player state unchanged")
		for collection in [sim.combat.projectiles,sim.combat.skills.zones,sim.combat.constellation.pending]:check(collection.size()==1 and collection[0].owner==2,job+" owner effects isolated")
		check(not enemy.job_status.has("bleed") and enemy.job_status.has("weaken"),job+" enemy statuses isolated")
		check(not enemy.constellation_marks.has("1") and enemy.constellation_marks.has("2") and enemy.taunt_time==0,job+" marks and taunt isolated")
		# Actual rescue input advances the world; no artificial resurrection writes.
		sim.enemies.clear();ally.pos=p.pos;ally.charge_time=-1.;ally.dodge_time=0.
		check(sim.action(2,"interact"),job+" rescue begins")
		for i in range(31):sim.set_input(2,Vector2.ZERO,Vector2.RIGHT,false,true);sim.tick(.1)
		check(p.hp>0 and p.down_time==0 and p.gold==gold,job+" rescue without death penalty")
		check(p.constellation_state.last_time==0 and p.constellation_state.move_time==0 and p.constellation_state.support_time==0,job+" rescue cannot restore old combo")
		check(p.job_state.buffs.is_empty() and p.barrier_time==0 and p.haste_time==0,job+" rescue cannot restore old buffs")
		check(p.invulnerable>0,job+" rescue grants fresh protection")
	# The same cleanup also applies when there is no rescuer and after disconnection.
	for solo in [true,false]:
		var sim=Sim.new(931,"cave",12);sim.enemies.clear();var p=sim.add_player(1,"검증");prime(sim,p);p.gold=100
		if solo:sim.player_defeated(p)
		else:sim.reset_after_defeat(1)
		check(p.constellation_state.last_time==0 and p.job_state.buffs.is_empty(),"solo/disconnect cleanup")
		check(sim.combat.projectiles.is_empty() and sim.combat.skills.zones.is_empty() and sim.combat.constellation.pending.is_empty(),"solo/disconnect pending cleanup")
		check(p.skill_cooldowns.test_skill==9. and p.potion_cd==4.,"solo/disconnect keeps cooldown")
		if solo:check(p.hp==p.max_hp and p.gold==90,"solo penalty unchanged")
	var sim=Sim.new(931,"cave",12);sim.enemies.clear();var p=sim.add_player(1,"수호");var ally=sim.add_player(2,"동료")
	p.pos=Vector2(sim.map.rooms[1]);p.class_id="tank";p.level=60;p.skill_ranks={"tank_a04":1};p.skill_loadout={"skill_q":"tank_a04"};sim.combat.jobs.reset(p);sim.recalculate(p);ally.pos=p.pos
	check(sim.action(1,"skill_q"),"actual shared guard starts")
	for i in range(20):sim.tick(.05)
	check(sim.combat.jobs.value(ally,"defense")>0,"actual shared guard reaches ally after windup")
	var shared=ally.job_state.buffs.duplicate(true)
	sim.player_defeated(p)
	check(ally.job_state.buffs==shared and p.job_state.buffs.is_empty(),"already delivered ally buff keeps duration after caster down")
	print("COMBAT_LIFECYCLE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
