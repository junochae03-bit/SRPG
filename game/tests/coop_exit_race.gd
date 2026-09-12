extends SceneTree
class DelayedSession extends "res://scripts/coop_session.gd":
	var ack_delay=0.
	@rpc("authority","call_remote","reliable",2)
	func exit_checkpoint(token:String,data:Dictionary,revision:int,last_serial:int):
		if ack_delay>0:await get_tree().create_timer(ack_delay).timeout
		super.exit_checkpoint(token,data,revision,last_serial)
var failures=0
func check(ok:bool,message:String):
	if not ok:failures+=1;printerr(message)
func _initialize():run.call_deferred()
func run():
	var options={}
	for arg in OS.get_cmdline_user_args():
		var pair=arg.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1]
	var session=DelayedSession.new();session.name="Session";root.add_child(session);session.save_directory=options.directory
	var sim=preload("res://scripts/simulation.gd").new(733,"town");sim.add_player(1,"종료 경계 검사").tutorial_done=true
	var data=sim.persistent(1);data.world_seed=733;check(session.write_save(data,session.save_path()),"fixture saved")
	var host=options.role=="host";session.ack_delay=3. if options.role=="guest" else 0.
	check(session.host_room(1,int(options.port)) if host else session.join_room("127.0.0.1",1,int(options.port)),"connection requested")
	if host:print("HOST_READY")
	var deadline=Time.get_ticks_msec()+18000
	if options.role=="late":
		while session.network_role!="offline" and not session.connected and Time.get_ticks_msec()<deadline:await create_timer(.05).timeout
		check(not session.connected and session.room_status.contains("닫는 중") and session.latest_checkpoint.is_empty(),"shutdown rejects newcomer before actor registration")
	else:
		while (not session.connected or session.state.players.size()<2) and Time.get_ticks_msec()<deadline:await create_timer(.05).timeout
		check(session.connected and session.state.players.size()==2,"host and delayed guest joined")
		if host:
			print("HOST_CLOSING")
			check(await session.leave_room(),"host closes after original guest disk ACK")
		else:
			while session.connected and Time.get_ticks_msec()<deadline:await create_timer(.05).timeout
			check(not session.connected and session.exit_result and session.parse_save(session.save_path())!=null,"delayed guest checkpoint is durable")
	print("COOP_NETWORK ",options.role," failures=",failures)
	session.queue_free();await process_frame;quit(0 if failures==0 else 1)
