extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Revival=preload("res://scripts/revival_aftereffects.gd")
const World=preload("res://scripts/world_catalog.gd")
const Ops=preload("res://scripts/town_operations.gd")
const Session=preload("res://scripts/local_session.gd")
class MemorySession extends "res://scripts/local_session.gd":
	func write_save(_data:Dictionary,_path:String)->bool:return true
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func fixture():
	var sim=Sim.new(712,"forest");sim.enemies.clear()
	var p=sim.add_player(1,"부상자");var q=sim.add_player(2,"구조자")
	p.pos=sim.map.spawn;q.pos=p.pos;p.hp=0;sim.player_defeated(p)
	return sim
func hold(sim,id:int,seconds:float):
	for i in range(roundi(seconds/.05)):
		sim.set_input(id,Vector2.ZERO,Vector2.RIGHT,false,true);sim.tick(.05)
func treat(sim,p,facility,operation)->bool:
	p.pos=World.FACILITIES[facility].pos
	return sim.action(p.id,"facility",JSON.stringify({"facility":facility,"operation":operation}))
func run():
	var sim=fixture();var p=sim.players[1];var q=sim.players[2]
	check(sim.action(2,"interact"),"tap consumed by nearby rescue")
	for i in range(62):sim.tick(.05)
	check(p.hp==0 and not q.has("revive_target"),"tap alone cannot rescue")
	hold(sim,2,.5);sim.set_input(2,Vector2.ZERO,Vector2.RIGHT,false,false)
	check(not q.has("revive_target") and not p.revival_injury,"release cancels without injury")
	hold(sim,2,2.9);sim.tick(.36)
	check(p.hp==0 and not q.has("revive_target"),"expired input before completion cancels")
	hold(sim,2,.5)
	check(not q.has("revive_target"),"held latch prevents automatic retry after interruption")
	sim.set_input(2,Vector2.ZERO,Vector2.RIGHT)
	hold(sim,2,3.)
	check(p.hp>0 and p.down_time==0 and p.revival_weakness and p.revival_injury,"continuous hold rescues with both injuries")
	check(p.hp==maxi(1,roundi(p.max_hp*.35)),"rescue health uses reduced max HP")
	check(p.invulnerable>0 and sim.dirty.has(1),"rescue has protection and save checkpoint dirtiness")
	check(Revival.attack(p,100)==85,"weakness reduces attack exactly once")
	var sample={"max_hp":1000,"defense":100,"magic_defense":100,"revival_weakness":true,"revival_injury":true}
	Revival.apply_stats(sample)
	check(sample.max_hp==800 and sample.defense==85 and sample.magic_defense==85,"independent physical magical defense and health factors")
	var current=p.hp;var maximum=p.max_hp
	for i in range(10):sim.recalculate(p)
	check(p.hp==current and p.max_hp==maximum,"recalculation neither stacks nor heals")
	p.hp=0;p.down_time=10.;sim.recalculate(p)
	check(p.hp==0,"recalculate cannot revive downed player")
	sim.respawn_player(p)
	check(p.revival_weakness and p.revival_injury and p.max_hp==maximum,"defeat recovery preserves injuries")
	var saved=sim.persistent(1);saved.world_seed=712
	var session=Session.new()
	check(session.validate_save(saved.duplicate(true))!=null,"new save with production stats and injuries validates")
	for key in Revival.FIELDS:
		for bad in [null,0,1,"true",[],{}]:
			var malformed=saved.duplicate(true);malformed[key]=bad
			check(session.validate_save(malformed)==null,"malformed injury type rejected "+key)
	var legacy=saved.duplicate(true)
	for key in Revival.FIELDS:legacy.erase(key)
	check(session.validate_save(legacy.duplicate(true))!=null,"missing legacy injuries accepted")
	var town=Sim.new(712,"town");var restored=town.add_player(1,"귀환자",saved)
	check(restored.revival_weakness and restored.revival_injury and restored.max_hp==maximum,"return reconstruction preserves both injuries")
	var healthy=town.add_player(2,"기존 기록",legacy)
	check(not healthy.revival_injury and not healthy.revival_weakness,"old save defaults healthy")
	var peer=town.snapshot(2).players[1]
	check(peer.revival_injury and peer.revival_weakness and peer.max_hp==maximum,"peer snapshot contains both injuries")
	check(not saved.has("revive_target") and not saved.has("interact_held"),"transient inputs are never persisted")
	restored.gold=1000;restored.hp=10
	var gold=restored.gold
	check(treat(town,restored,"church","treat"),"church treatment accepted")
	check(not restored.revival_weakness and restored.revival_injury and restored.hp==10 and restored.max_hp==maximum,"church treats weakness only without healing")
	check(restored.gold==gold-10,"church exact initial price")
	gold=restored.gold
	check(not treat(town,restored,"church","treat") and restored.gold==gold,"repeat church treatment cannot charge twice")
	for operation in ["rest","resupply_small","resupply"]:
		restored.revival_weakness=true;restored.revival_injury=true;town.recalculate(restored);restored.hp=1;restored.gold=1000
		var before=town.persistent(1).duplicate(true);var quote=Ops.quote(restored,"inn",operation)
		check(quote.reason.is_empty() and town.persistent(1)==before,"inn quote is read only "+operation)
		check(treat(town,restored,"inn",operation),"inn treatment "+operation)
		check(restored.revival_weakness and not restored.revival_injury and restored.hp==restored.max_hp and restored.max_hp==Revival.normal_max_hp(restored),"inn restores normal maximum and leaves weakness "+operation)
	check(treat(town,restored,"church","treat") and not restored.revival_injury and not restored.revival_weakness,"reverse treatment order removes both")
	restored.revival_weakness=true;restored.revival_injury=true;town.recalculate(restored);restored.gold=0
	var before=town.persistent(1).duplicate(true)
	check(not treat(town,restored,"inn","rest") and town.persistent(1)==before,"unaffordable rest has no side effects")
	check(not treat(town,restored,"church","treat") and town.persistent(1)==before,"unaffordable church has no side effects")
	check(town.map.walkable(World.resident_pos("church")) and World.nearest(World.resident_pos("church"))=="church","church resident walkable and selected")
	check(reachable(town.map,town.map.spawn,World.FACILITIES.church.pos),"church accessible from town spawn")
	for id in [1,2]:
		var cancelled=fixture();var rescuer=cancelled.players[2]
		hold(cancelled,2,.1)
		if id==1:cancelled.set_input(2,Vector2.RIGHT,Vector2.RIGHT,false,true)
		else:cancelled.action(2,"cancel_charge")
		check(not rescuer.has("revive_target"),"movement or focus cancellation ends rescue")
	var simultaneous=fixture();var third=simultaneous.add_player(3,"동시 구조");third.pos=simultaneous.players[1].pos
	for i in range(60):
		for id in [2,3]:simultaneous.set_input(id,Vector2.ZERO,Vector2.RIGHT,false,true)
		simultaneous.tick(.05)
	check(simultaneous.events.filter(func(e):return e.get("type","")=="notice" and e.get("owner",0)==1 and "동료가 구조" in e.get("text","")).size()==1,"two rescuers complete exactly once")
	for reason in ["distance","wall","departure","target_removed","rescuer_down"]:
		var invalid=fixture();var rescuer=invalid.players[2];hold(invalid,2,.1)
		match reason:
			"distance":invalid.players[1].pos+=Vector2(3,0)
			"wall":invalid.map.facility_cells[Vector2i(rescuer.pos)]=true
			"departure":invalid.players[1].network_leaving=true
			"target_removed":invalid.players.erase(1)
			"rescuer_down":rescuer.hp=0
		Revival.tick(invalid,rescuer,.05)
		check(not rescuer.has("revive_target"),"invalid rescue cancelled "+reason)
	var candidates=fixture();var nearer=candidates.add_player(3,"다른 부상자");nearer.pos=candidates.players[2].pos;nearer.hp=0;nearer.down_time=20.
	candidates.players[1].pos+=Vector2(.5,0)
	check(Revival.candidate(candidates,candidates.players[2]).id==3,"closest target chosen")
	candidates.players[1].pos=nearer.pos
	check(Revival.candidate(candidates,candidates.players[2]).id==1,"equal distance resolved by stable player ID")
	var damaged=fixture();var rescuer=damaged.players[2]
	for actor in damaged.players.values():actor.pos=Vector2(damaged.map.rooms[1])
	hold(damaged,2,.1)
	var enemy=damaged.spawn_enemy("rat",rescuer.pos+Vector2(.4,0),1);enemy.damage=1
	damaged.monster_attacks.damage(enemy,rescuer,{"multiplier":1.,"drain":0.,"slow":0.,"knock":0.})
	check(not rescuer.has("revive_target") and rescuer.hp<rescuer.max_hp,"actual pattern damage cancels held rescue")
	var local=MemorySession.new();local.sim=fixture();local.local_id=2;local.connected=true;local.world_seed=712
	local.sim.map.floor_number=1;local.sim.map.exit_position=local.sim.players[2].pos
	check(local.act("interact") and local.sim.map.floor_number==1,"rescue consumes exit interaction before travel")
	local.send_input(Vector2.ZERO,Vector2.RIGHT,false,true);local.paused=true;local.send_input(Vector2.ZERO,Vector2.RIGHT,false,true)
	check(not local.sim.players[2].has("revive_target"),"paused local input releases rescue")
	local.connected=false;local.free();session.free()
	print("REVIVAL_AFTEREFFECTS_TESTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func reachable(map,start:Vector2,end:Vector2)->bool:
	var queue=[Vector2i(start)];var seen={queue[0]:true};var index=0
	while index<queue.size():
		var cell=queue[index];index+=1
		if cell==Vector2i(end):return true
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next=cell+step
			if not seen.has(next) and map.walkable(Vector2(next)):seen[next]=true;queue.append(next)
	return false
