extends SceneTree
const Session=preload("res://scripts/local_session.gd")
func _initialize():run.call_deferred()
func run():
	var args={}
	for arg in OS.get_cmdline_user_args():
		var pair=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var session=Session.new();root.add_child(session);session.set_physics_process(false)
	session.save_directory=args["save-dir"];session.start_game("전리품 재시작 검사",1)
	assert(session.travel("forest"))
	var p=session.sim.players[1];var elite=session.sim.enemies.values().filter(func(e):return e.elite)[0]
	# A controlled final hit exercises attack -> kill -> table -> pickup -> save.
	# Traversal and ordinary combat run separately in the 40-second bot journey.
	elite.hp=1;p.pos=elite.pos-Vector2.RIGHT*.8;p.aim=Vector2.RIGHT;p.attack_cd=0
	var old_kills=p.kills;var boss_kills=p.boss_kills;var old_items=p.inventory.size()
	assert(session.act("attack"));assert(elite.hp==0 and p.kills==old_kills+1 and p.boss_kills==boss_kills)
	var guaranteed=session.sim.drops.values().filter(func(d):return d.item.category=="weapon" and d.item.rarity>=1)
	assert(guaranteed.size()>=1)
	var item=guaranteed[0].item.duplicate(true);p.pos=guaranteed[0].pos
	assert(session.act("interact"));assert(p.inventory.size()>old_items and p.inventory.any(func(i):return i==item))
	session.save_game()
	var report={}
	for key in ["level","xp","gold","kills","boss_kills","inventory","equipment","equipped","bag_positions","materials"]:report[key]=p[key]
	var file=FileAccess.open(args.report,FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(report));file.close()
	session.disconnect_game();session.queue_free();await process_frame
	print("PROCESS_ELITE_LOOT_PASS gear=",item.name," rarity=",item.rarity);quit()
