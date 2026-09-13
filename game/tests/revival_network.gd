extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_catalog.gd")
var session
var options={}
var checks=0
var failures=[]
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair=arg.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1]
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func wait_for(predicate:Callable,label:String):
	var deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not predicate.call():await create_timer(.05).timeout
	check(predicate.call(),label)
func barrier(stage:String):
	var file=FileAccess.open(options.directory.path_join(stage),FileAccess.WRITE);file.store_string("ready");file.close()
	await wait_for(func():return ["host","guest"].all(func(role):return FileAccess.file_exists(options.directory.get_base_dir().path_join(role+"/"+stage))),"barrier "+stage)
func hold():
	for i in range(66):
		session.send_input(Vector2.ZERO,Vector2.RIGHT,false,true)
		await create_timer(.05).timeout
	session.send_input(Vector2.ZERO,Vector2.RIGHT,false,false)
func run():
	session=preload("res://scripts/coop_session.gd").new();session.name="Session";root.add_child(session);session.save_directory=options.directory
	var fixture=Sim.new(719,"town");var p=fixture.add_player(1,"구조 검증");p.gold=1000;p.tutorial_done=true
	var saved=fixture.persistent(1);saved.world_seed=719
	check(session.write_save(saved,session.save_path()),"isolated schema8 save")
	var host=options.role=="host"
	check(session.host_room(1,int(options.port)) if host else session.join_room("127.0.0.1",1,int(options.port)),"real ENet connection")
	if host:print("REVIVAL_HOST_READY")
	await wait_for(func():return session.connected and session.state.players.size()==2,"two peers")
	if session.state.players.size()!=2:finish();return
	var guest=session.state.players.keys().filter(func(id):return id!=1)[0]
	await barrier("joined")
	if host:
		check(session.change_map("cave",1),"dungeon map")
		session.sim.enemies.clear()
		for actor in session.sim.players.values():actor.pos=session.sim.map.exit_position
		p=session.sim.players[1];p.hp=0;session.sim.player_defeated(p);session.refresh();session.publish_snapshot()
	await wait_for(func():return session.state.players[1].get("down_time",0)>0,"host down replicated")
	await barrier("down")
	if not host:check(session.act("interact"),"tap RPC accepted near exit")
	await create_timer(3.3).timeout
	check(session.sim.map.floor_number==1 and session.state.players[1].hp==0,"tap cannot rescue or trigger exit travel")
	await barrier("tap")
	if not host:await hold()
	await wait_for(func():return session.state.players[1].hp>0,"guest held-input rescues host")
	check(session.state.players[1].revival_injury and session.state.players[1].revival_weakness,"host aftereffects replicated")
	await barrier("first_rescue")
	if host:
		p=session.sim.players[guest];p.hp=0;session.sim.player_defeated(p);session.refresh();session.publish_snapshot()
	await wait_for(func():return session.state.players[guest].get("down_time",0)>0,"guest down replicated")
	await barrier("guest_down")
	if host:await hold()
	await wait_for(func():return session.state.players[guest].hp>0,"host held-input rescues guest")
	if not host:
		await wait_for(func():return session.latest_checkpoint.get("revival_injury",false) and session.latest_checkpoint.get("revival_weakness",false),"guest checkpoint preserves injuries")
	await barrier("both_injured")
	if host:check(session.change_map("town",0),"return keeps injuries")
	await wait_for(func():return session.sim.map.zone=="town","town replicated")
	check(session.state.players.values().all(func(actor):return actor.revival_weakness and actor.revival_injury),"return cures nobody")
	if host:
		session.sim.players[guest].pos=World.FACILITIES.church.pos;session.refresh();session.publish_snapshot()
	await wait_for(func():return session.state.players[guest].pos==World.FACILITIES.church.pos,"church location replicated")
	await barrier("church")
	if not host:check(session.act("facility",JSON.stringify({"facility":"church","operation":"treat"})),"guest requests church")
	await wait_for(func():return not session.state.players[guest].revival_weakness,"church result replicated")
	check(session.state.players[guest].revival_injury and session.state.players[1].revival_weakness,"church treatment is personal and separate")
	if not host:check(session.state.players[guest].gold==990,"one church charge")
	await barrier("church_done")
	if host:
		session.sim.players[guest].pos=World.FACILITIES.inn.pos;session.refresh();session.publish_snapshot()
	await wait_for(func():return session.state.players[guest].pos==World.FACILITIES.inn.pos,"inn location replicated")
	if not host:check(session.act("facility",JSON.stringify({"facility":"inn","operation":"rest"})),"guest requests inn")
	await wait_for(func():return not session.state.players[guest].revival_injury,"inn treatment replicated")
	p=session.state.players[guest]
	check(p.hp==p.max_hp and not p.revival_weakness,"inn restores max and current HP")
	check(session.state.players[1].revival_injury and session.state.players[1].revival_weakness,"other player retains both")
	if not host:
		await wait_for(func():return not session.latest_checkpoint.get("revival_injury",true) and not session.latest_checkpoint.get("revival_weakness",true),"treated checkpoint replicated")
		check(session.state.players[guest].gold==980,"inn charge exact")
	await barrier("treated")
	if not host:
		check(await session.leave_room(),"orderly client departure")
		var disk=session.parse_save(session.save_path())
		check(disk!=null and not disk.revival_injury and not disk.revival_weakness,"final exit checkpoint persists treatment")
	else:
		await wait_for(func():return session.sim.players.size()==1,"guest departure acknowledged")
		check(session.sim.players[1].revival_weakness and session.sim.players[1].revival_injury,"host injuries survive guest departure")
	finish()
func finish():
	print("REVIVAL_NETWORK_TESTS role=%s checks=%d failures=%d"%[options.role,checks,failures.size()])
	if session!=null:
		session.connected=false
		if session.network_peer!=null:session.network_peer.close()
		session.free()
	quit(0 if failures.is_empty() else 1)
