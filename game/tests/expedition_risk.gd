extends SceneTree
const Risk=preload("res://scripts/expedition_risk.gd")
const Sim=preload("res://scripts/simulation.gd")
const Party=preload("res://scripts/party_rules.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var checks=0
var failures=[]
class Session extends "res://scripts/coop_session.gd":
	var refuse_save=false
	func write_save(data:Dictionary,path:String)->bool:return false if refuse_save else super.write_save(data,path)
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	for depth in range(1,101):
		check(Risk.cap(depth)==(0 if depth%10==0 else Risk.CAPS[int((depth-1)/10)]),"regional cap B%d"%depth)
		check(Risk.normalize(depth,99)==Risk.cap(depth) and Risk.normalize(depth,-1)==0,"construction bounded B%d"%depth)
	for chapter in range(10):
		var depth=chapter*10+1;var zone=Abyss.config(depth).terrain
		for seed_value in [81,741,9241]:
			var normal=Sim.new(seed_value,zone,depth)
			for rank in range(1,Risk.cap(depth)+1):
				var sim=Sim.new(seed_value,zone,depth,rank);var copy=Sim.new(seed_value,zone,depth,rank)
				check(sim.map.encounters==copy.map.encounters,"deterministic added role packs")
				check(sim.map.floor_cells==normal.map.floor_cells and sim.map.connections==normal.map.connections and sim.map.rooms==normal.map.rooms,"risk never inflates or changes geometry")
				check(sim.enemies.size()==normal.enemies.size()+rank*2,"actual reinforcement count")
				check(sim.map.environment==normal.map.environment,"environment independently selected")
				var extra=sim.enemies.values().filter(func(e):return e.get("risk_reinforcement",false))
				check(extra.filter(func(e):return e.encounter_room==7).size()==2,"guardian approach has a mandatory role pair")
				for e in extra:
					check(sim.map.walkable(e.pos) and e.pos.distance_to(sim.map.spawn)>=8. and e.pos.distance_to(sim.map.exit_position)>=5.,"reinforcement respects clear arrival and exit")
					check(sim.enemies.values().all(func(other):return other.id==e.id or other.pos.distance_to(e.pos)>=1.99),"no reinforcement stacks silhouettes")
				for id in normal.enemies:
					var a=normal.enemies[id];var b=sim.enemies[id]
					check(a.kind==b.kind and a.pos==b.pos and b.max_hp==roundi(a.max_hp*(1.+rank*.1)),"existing placement preserved and health scaled once")
				for id in range(1,7):sim.add_player(id,"동료 %d"%id)
				var health=sim.enemies[1].max_hp;Party.rescale(sim)
				check(sim.enemies[1].max_hp==roundi(health*Party.health_factor(6)),"party health multiplier follows independent risk multiplier")
				Party.rescale(sim);check(sim.enemies[1].max_hp==roundi(health*Party.health_factor(6)),"repeat party rescale never compounds risk")
	var sim=Sim.new(741,"town");var p=sim.add_player(1,"별하");p.highest_floor=100;p.level=100;p.tutorial_done=true
	var friend=sim.add_player(2,"여울");friend.highest_floor=100;friend.level=100;friend.tutorial_done=true
	for request in [{"floor":1,"risk":1},{"floor":10,"risk":1},{"floor":12,"risk":2},{"floor":12,"risk":-1},{"floor":12,"risk":.5},{"floor":101,"risk":0},{"floor":"12","risk":0},{"floor":12,"risk":0,"extra":1}]:
		var before=sim.departure_plan.duplicate(true)
		check(not sim.action(1,"plan_expedition",JSON.stringify(request)) and sim.departure_plan==before,"reject invalid risk plan "+str(request))
	check(not sim.action(2,"plan_expedition",'{"floor":12,"risk":1}'),"guest cannot alter shared risk")
	check(sim.action(1,"plan_expedition",'{"floor":12,"risk":1}'),"host chooses valid regional risk")
	var revision=sim.departure_plan.revision
	check(sim.action(1,"plan_expedition",'{"floor":12,"risk":1}') and sim.departure_plan.revision==revision,"same plan is idempotent")
	var session=Session.new();root.add_child(session);session.set_physics_process(false)
	session.save_directory=ProjectSettings.globalize_path("res://../runtime/risk/"+str(Time.get_ticks_usec()));session.sim=sim;session.connected=true;session.refresh()
	session.network_role="host";session.ready_players={1:true,2:true}
	check(session.host_action(1,"plan_expedition",'{"floor":31,"risk":2}') and session.ready_players.values().all(func(x):return not x),"changed plan clears every ready flag")
	check(not session.host_action(2,"ready","true:"+str(revision)) and not session.ready_players[2],"stale acknowledgment cannot ready changed plan")
	check(not session.host_action(2,"ready","true"),"bare ready cannot acknowledge explicit plan")
	check(session.host_action(2,"ready",session.ready_argument(true)),"current plan acknowledgment succeeds")
	session.network_role="offline";sim.players.erase(2)
	check(not session.enter_floor(32),"departure cannot substitute a different floor after selection")
	session.refuse_save=true
	check(not session.enter_floor(31) and session.sim==sim and session.sim.departure_plan.risk==2,"failed save keeps original map and chosen risk")
	session.refuse_save=false
	check(session.enter_floor(31) and session.sim.map.risk_level==2 and session.sim.enemies.size()==27,"chosen risk reaches real generated map")
	sim=session.sim;p=sim.players[1]
	check(not sim.action(1,"plan_expedition",'{"floor":31,"risk":0}'),"cannot lower risk after entering")
	check(not sim.persistent(1).has("departure_plan") and not sim.persistent(1).has("risk_level"),"map risk is not personal progression")
	# Real kill rewards: verify probability wiring against the RNG's first draw.
	var enemy=sim.enemies[1];sim.loot_tables.tables={enemy.kind:[{"kind":"material","material":"ore","chance":.5,"amount":1}]}
	for seed_value in range(1,81):
		var rng=RandomNumberGenerator.new();rng.seed=seed_value;var expected=rng.randf()<.5*(1.+.15*2)
		sim.rng.seed=seed_value;sim.drops.clear();enemy.hp=enemy.max_hp;enemy.erase("rewarded");sim.kill(1,enemy)
		check(not sim.drops.is_empty()==expected,"real kill uses risk drop probability")
	var guardian=sim.enemies.values().filter(func(e):return e.get("guardian",false))[0]
	friend=sim.add_player(2,"여울");friend.pos=sim.map.spawn;sim.drops.clear();sim.kill(1,guardian)
	var reward=sim.drops.values().filter(func(d):return d.item.id.begins_with("risk-"))
	check(reward.size()==2 and reward.all(func(d):return d.item.amount==4 and d.item.material=="essence"),"guardian creates guaranteed personal essence for both players")
	check(reward[0].owner!=reward[1].owner,"guardian reward has independent ownership")
	var drop_count=sim.drops.size();sim.kill(2,guardian);check(sim.drops.size()==drop_count,"duplicate kill cannot repeat risk bonus")
	check(sim.snapshot(1).drops.values().all(func(d):return d.owner==1),"risk bonus follows private loot filter")
	sim.players.erase(2);p.pos=sim.map.exit_position
	check(session.enter_floor(32) and session.sim.map.risk_level==2,"risk continues to next normal floor")
	check(session.travel("town") and session.sim.departure_plan.risk==0 and session.sim.map.risk_level==0,"return resets risk for next expedition")
	session.act("plan_expedition",'{"floor":19,"risk":1}');check(session.enter_floor(19),"start pre-raid risk expedition")
	for depth in [20,21]:
		for e in session.sim.enemies.values():e.hp=0
		session.sim.players[1].pos=session.sim.map.exit_position
		check(session.enter_floor(depth),"traverse raid boundary")
		check(session.sim.map.risk_level==(0 if depth==20 else 1),"raid is neutral and next normal floor restores selected risk")
	check(session.sim.departure_plan.risk==1,"raid does not erase expedition choice")
	session.connected=false;session.queue_free();await process_frame
	print("EXPEDITION_RISK checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
