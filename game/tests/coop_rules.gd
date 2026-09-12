extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Party=preload("res://scripts/party_rules.gd")
var checks=0
var failures=[]
class RecoveringSession extends "res://scripts/coop_session.gd":
	var block_save=true
	func write_save(data:Dictionary,path:String)->bool:
		return false if block_save else super.write_save(data,path)
class Arena extends RefCounted:
	var end=3.
	func walkable(at:Vector2)->bool:return at.x<end
	func in_town(_at:Vector2)->bool:return false
	func line_clear(_a:Vector2,_b:Vector2)->bool:return true
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);printerr(message)
func _initialize():run.call_deferred()
func run():
	var sim=Sim.new(520,"forest",1);sim.enemies.clear()
	var db=preload("res://scripts/game_database.gd").snapshot(false,false)
	check(db.metadata.coop_rules==Party.configuration(),"DB exports runtime co-op parameters")
	var p=sim.add_player(1,"검사");var q=sim.add_player(2,"궁수");p.tutorial_done=true;q.tutorial_done=true
	var guardian=sim.spawn_enemy("goblin_captain",Vector2(sim.map.rooms[1]),5);guardian.guardian=true
	p.pos=guardian.pos;q.pos=sim.map.spawn
	sim.kill(1,guardian)
	check(p.highest_floor==2 and q.highest_floor==2,"guardian progression shared without last-hit lock")
	var amounts=[p.gold,q.gold,p.kills,q.kills];sim.kill(2,guardian)
	check(amounts==[p.gold,q.gold,p.kills,q.kills],"guardian reward cannot be duplicated")
	check(sim.snapshot(1).drops.values().all(func(drop):return drop.owner==1),"loot owner filter")
	var e=sim.spawn_enemy("warden",Vector2(sim.map.rooms[1]),10,true);e.hp=e.max_hp*.5
	var base=e.max_hp;var meter=e.stagger.max_value;Party.rescale(sim)
	check(e.max_hp==roundi(base*1.65) and absf(float(e.hp)/e.max_hp-.5)<.01,"two-player scaling preserves health percentage")
	check(is_equal_approx(e.stagger.max_value,meter*1.45),"stagger scale")
	var almost_dead=sim.spawn_enemy("goblin_captain",e.pos,1);Party.rescale(sim);almost_dead.hp=1
	sim.players.erase(2);Party.rescale(sim)
	check(e.max_hp==base and is_equal_approx(e.stagger.max_value,meter),"leaver scaling returns solo values")
	check(almost_dead.hp==1 and not almost_dead.get("rewarded",false),"leaver cannot round a living enemy to unrewarded death")
	p.gold=100;p.hp=0;sim.player_defeated(p)
	check(p.hp==p.max_hp and p.gold==90 and p.get("down_time",0)==0,"solo never requires a rescuer")
	q=sim.add_player(2,"구조자");sim.enemies.clear();p.hp=0;sim.player_defeated(p)
	check(p.hp==0 and p.down_time==20.,"coop enters downed state")
	var target_enemy=sim.spawn_enemy("goblin_captain",p.pos+Vector2(.5,0),1)
	check(not sim.combat.hit(p,target_enemy,100) and p.hp==0,"downed projectiles cannot deal damage or heal through lifesteal")
	sim.enemies.clear()
	q.pos=p.pos;check(sim.action(2,"interact"),"nearby player starts rescue")
	sim.tick(1.);sim.set_input(2,Vector2.RIGHT,Vector2.RIGHT)
	check(not q.has("revive_target"),"movement cancels rescue")
	sim.set_input(2,Vector2.ZERO,Vector2.RIGHT);sim.action(2,"interact")
	for i in range(31):sim.tick(.1)
	check(p.hp>0 and p.down_time==0. and not q.has("revive_target"),"three-second rescue succeeds")
	var original=sim.map;sim.players.clear();sim.enemies.clear();e=sim.spawn_enemy("warden",Vector2.ZERO,10,true);e.raid=true;e.pattern=3
	var arena=Arena.new();sim.map=arena
	sim.monster_attacks.begin(e,Vector2.RIGHT)
	check(e.wall_charge and e.windup>=1.5,"charge has fixed telegraph")
	sim.monster_attacks.release(e)
	check(e.pos.x<3 and e.stagger.state=="down","wall stops charge and creates vulnerability")
	arena.end=100;e.pos=Vector2.ZERO;preload("res://scripts/boss_stagger.gd").initialize(e);e.pattern=3
	sim.monster_attacks.begin(e,Vector2.RIGHT);sim.monster_attacks.release(e)
	check(is_equal_approx(e.pos.x,6.5) and e.stagger.state=="ready","open-space charge has no free stagger")
	sim.map=original
	var recovery=RecoveringSession.new();root.add_child(recovery)
	recovery.save_directory=ProjectSettings.globalize_path("res://../runtime/coop-recovery-"+str(Time.get_ticks_usec()))
	var saved=Sim.new(34,"town");saved.add_player(1,"저장 복구").tutorial_done=true
	recovery.network_role="client";recovery.latest_checkpoint=saved.persistent(1);recovery.latest_checkpoint.world_seed=34
	recovery.close_network("검사 종료")
	check(not recovery.recovery_checkpoint.is_empty() and not recovery.recover_save(),"failed disconnect save remains recoverable")
	check(not recovery.create_character({"name":"덮어쓰기"},1),"new character cannot replace pending recovery")
	recovery.block_save=false
	check(recovery.recover_save() and recovery.parse_save(recovery.save_path()).name=="저장 복구","recovery writes original local slot")
	recovery.queue_free();await process_frame
	print("COOP_RULES checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
