extends SceneTree
const S=preload("res://scripts/simulation.gd")
const A=preload("res://scripts/abyss_catalog.gd")
const P=preload("res://scripts/progression.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var local=preload("res://scripts/local_session.gd").new();root.add_child(local);local.set_physics_process(false);local.save_directory=ProjectSettings.globalize_path("res://../runtime/dungeon-v02/"+str(Time.get_ticks_usec()));local.start_game("탐사 검사",1)
	var p=local.sim.players[1]
	check(local.sim.map.zone=="forest" and not p.tutorial_done,"new save starts tutorial")
	check(not local.travel("town") and not local.enter_floor(1),"cannot bypass tutorial")
	for i in range(5):local.sim.kill(1,local.sim.enemies.values()[i])
	check(local.travel("town"),"five tutorial kills unlock town")
	p=local.sim.players[1];check(p.tutorial_done and p.quest_done and p.gold>=100,"town arrival tutorial reward")
	check(not local.enter_floor(2),"cannot skip uncleared floor")
	check(local.enter_floor(1),"enter first floor")
	var last_hp=0;var raids=0
	for floor_number in range(1,101):
		var cfg=A.config(floor_number);var sim=S.new(112+floor_number,cfg.terrain,floor_number);var player=sim.add_player(1,"100층 검사");player.level=100;player.tutorial_done=true
		check(sim.map.floor_number==floor_number and sim.enemies.size()==23,"roster floor "+str(floor_number))
		var guards=sim.enemies.values().filter(func(e):return e.get("guardian",false));check(guards.size()==1,"exact one guardian")
		var guard=guards[0];check(guard.boss==(floor_number%10==0),"boss every ten floors")
		for e in sim.enemies.values():
			check(sim.map.walkable(e.pos) and e.hp>0 and e.damage>0,"valid scaled spawn")
			check(not sim.loot_tables.tables.get(e.kind,[]).is_empty(),"separate monster drop table")
		if guard.boss:
			raids+=1;check(guard.hp>last_hp and guard.hp>sim.enemies[1].hp*15,"raid much tougher than regular and last raid");last_hp=guard.hp
			for phase in [1,2]:
				guard.phase=phase
				for sequence in range(3):guard.pattern=sequence;sim.monster_attacks.begin(guard,guard.pos+Vector2.RIGHT);check(not guard.attack_areas.is_empty(),"raid telegraph patterns")
		sim.kill(1,guard);var xp=player.xp;var gold=player.gold;sim.kill(1,guard)
		check(player.xp==xp and player.gold==gold,"no repeated corpse rewards")
		check(player.cleared_floor==floor_number and player.highest_floor==mini(100,floor_number+1),"floor clear unlock")
		if guard.boss:check(sim.drops.values().any(func(d):return d.item.get("rarity",0)>=2),"guaranteed raid gear")
		sim.tick(999);check(guard.hp==0,"cleared guardian never respawns in run")
	check(raids==10,"ten raid bosses")
	for f in range(1,101):
		for i in range(100):
			var grade=A.raid_grade(f,i/100.)
			check(grade<=4 and grade>=2 and (grade!=4 or f>=70),"bounded raid quality "+str(f))
	p=local.sim.players[1];p.level=100;p.pos=local.sim.map.exit_position
	check(not local.enter_floor(2),"live guardian blocks staircase")
	local.sim.kill(1,local.sim.enemies.values().filter(func(e):return e.get("guardian",false))[0])
	check(local.enter_floor(2),"cleared staircase advances one floor")
	check(not local.enter_floor(4),"stairs cannot skip")
	check(local.travel("town"),"return to safe hub")
	local.save_game();var saved=local.parse_save(local.save_path());check(saved!=null and saved.highest_floor==2 and saved.tutorial_done,"progress saved")
	local.start_game("",1);check(local.sim.map.zone=="town" and local.sim.players[1].highest_floor==2,"resume in town with unlocks")
	local.connected=false;local.queue_free();print("DUNGEON_V02_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
