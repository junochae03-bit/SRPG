extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Inspect=preload("res://scripts/enemy_inspection.gd")
const Vision=preload("res://scripts/dungeon_vision.gd")
const DB=preload("res://scripts/game_database.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var sim=Sim.new(31,"cave",1);sim.enemies.clear();sim.map.floor_cells.clear()
	for x in range(1,75):
		for y in range(1,25):sim.map.floor_cells[Vector2i(x,y)]=true
	for id in range(1,7):
		var p=sim.add_player(id,"동료%d"%id);p.pos=Vector2(id*10,10)
		for i in range(4):sim.spawn_enemy("rat",p.pos+Vector2(i,2),1)
	for id in range(1,7):sim.awareness.emit(id,sim.players[id].pos,6)
	check(sim.enemies.values().filter(func(e):return e.get("heard_until",0)>sim.clock).size()==4,"six separated sounds share four listener reservations")
	check(sim.awareness.snapshot(1).pos==sim.players[1].pos and sim.awareness.snapshot(2).pos==sim.players[2].pos,"feedback belongs to sound owner")
	check(sim.snapshot(1).noise==sim.awareness.snapshot(1) and not sim.snapshot(1).noise.has("responders"),"private pulse does not reveal unseen enemies")
	for enemy in sim.enemies.values():
		if enemy.get("heard_until",0)>sim.clock:enemy.awareness_state="engaged"
	sim.clock=1.
	check(sim.awareness.emit(2,sim.players[2].pos,6)==0,"engaged sound listeners still reserve the party cap")
	sim.enemies[1].hp=0;sim.clock=2.
	check(sim.awareness.emit(2,sim.players[2].pos,6)==1,"death releases one reservation")
	sim.clock=9.1
	check(sim.awareness.emit(3,sim.players[3].pos,6)==3,"expiration releases three old reservations")
	check(sim.awareness.snapshot(1).is_empty(),"old feedback expires")
	sim.clock=20.
	check(sim.awareness.emit(4,sim.players[4].pos,6)==4,"full sound budget returns after expiration")
	var serial=sim.awareness.snapshot(4).serial
	check(sim.awareness.emit(4,sim.players[4].pos,6)==0 and sim.awareness.snapshot(4).serial==serial,"same-frame repeated sound does not rebuild feedback")
	check(sim.awareness.emit(4,sim.players[4].pos,8)<=4 and sim.awareness.snapshot(4).serial>serial,"louder same-frame action refreshes pulse without excess recruits")
	var p=sim.players[1];var enemy=sim.enemies[2];enemy.pos=p.pos;enemy.hp=1
	sim.kill(1,enemy)
	check(sim.inspection.corpses.size()==1,"real kill records one corpse")
	sim.kill(1,enemy);check(sim.inspection.corpses.size()==1,"duplicate kill does not duplicate corpse")
	var corpse=sim.inspection.corpses[0];var inventory_before=p.inventory.duplicate(true);var gold_before=p.gold
	var report=Inspect.description(corpse)
	check(report.subtitle.contains("처치됨") and report.health.begins_with("0 /"),"death record cannot show live health")
	check(not DB.detail("monsters",report.codex_id).is_empty(),"corpse links to real monster record")
	check(DB.query("drops",{"monster_id":report.codex_id}).total>0,"corpse links to actual drop table")
	check(p.inventory==inventory_before and p.gold==gold_before,"inspection is read only")
	var snapshot=sim.snapshot(2);snapshot.corpses[0].name="변경"
	check(sim.inspection.corpses[0].name!="변경","client record cannot mutate authority")
	enemy.rewarded=false;enemy.hp=1;sim.kill(1,enemy)
	check(sim.inspection.corpses.size()==2 and sim.inspection.corpses[0].record_id!=sim.inspection.corpses[1].record_id,"respawned source produces a distinct death record")
	for i in range(90):sim.inspection.record(enemy,sim.clock)
	check(sim.inspection.corpses.size()==Inspect.MAX_CORPSES,"corpse packet storage is bounded")
	var vision=Vision.new();vision.update(sim.map,sim.players,0.)
	check(Inspect.nearby(sim.inspection.corpses,p.pos,vision).size()==3,"only nearest three corpse markers")
	for member in sim.players.values():member.pos=Vector2(70,23)
	vision.update(sim.map,sim.players,1.)
	check(Inspect.nearby(sim.inspection.corpses,p.pos,vision).is_empty(),"undiscovered corpses have no marker or hover target")
	check(sim.snapshot(1).corpses.is_empty() and sim.snapshot(6).corpses.is_empty(),"authority omits all corpses outside current party sight")
	for member in sim.players.values():member.hp=0
	sim.players[2].hp=1;sim.players[2].pos=corpse.pos
	check(sim.snapshot(1).corpses.size()==Inspect.MAX_CORPSES,"living ally shares visible corpse records")
	sim.players[2].network_leaving=true
	check(sim.snapshot(1).corpses.is_empty(),"departing ally cannot preserve corpse visibility")
	sim.players[2].network_leaving=false;sim.players[2].pos=corpse.pos+Vector2(2,0)
	var wall=Vector2i(corpse.pos)+Vector2i.RIGHT
	for y in range(1,25):sim.map.floor_cells.erase(Vector2i(wall.x,y))
	sim.map.revision+=1
	check(sim.snapshot(2).corpses.is_empty(),"wall occlusion removes corpse data from wire snapshot")
	var fresh=Sim.new(31,"cave",1)
	check(fresh.inspection.corpses.is_empty() and fresh.awareness.snapshot(1).is_empty(),"new map has no stale investigation state")
	for kind in sim.balance.enemies:
		var e=sim.spawn_enemy(kind,Vector2(5,5),1)
		var info=Inspect.description(e)
		check(not info.shapes.is_empty() and not DB.detail("monsters",info.codex_id).is_empty(),"actual attack description and codex for "+kind)
	for floor_number in range(10,101,10):
		var raid=Sim.new(1,"cave",floor_number)
		var boss=raid.enemies.values().filter(func(e):return e.get("raid",false))[0]
		var info=Inspect.description(boss)
		check(info.codex_id=="raid:%03d"%floor_number and DB.query("drops",{"monster_id":info.codex_id,"floor":floor_number}).total>0,"specific raid codex and drops")
		check(info.shapes.contains("고리") and info.shapes.contains("부채꼴"),"raid attack vocabulary comes from real patterns")
	print("COMBAT_INFORMATION checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
