extends SceneTree
## A valid saved character using the previous wire version, while host has free slots.
class LegacySession extends "res://scripts/coop_session.gd":
 func prepare_network():
  if network_signals:return
  network_signals=true
  multiplayer.connected_to_server.connect(func():register_player.rpc_id(1,11,pending_character))
  multiplayer.connection_failed.connect(func():close_network("연결 실패"))
  multiplayer.server_disconnected.connect(func():close_network("서버 종료"))
var options={}
func _initialize():run.call_deferred()
func run():
 for arg in OS.get_cmdline_user_args():
  var pair=arg.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1]
 var session=LegacySession.new();session.name="Session";root.add_child(session);session.save_directory=options.directory
 var sim=preload("res://scripts/simulation.gd").new(531,"town");var p=sim.add_player(1,"이전 버전")
 p.tutorial_done=true;var data=sim.persistent(1);data.world_seed=531
 var ok=session.write_save(data,session.save_path()) and session.join_room("127.0.0.1",1,int(options.port))
 var until=Time.get_ticks_msec()+10000
 while session.network_role!="offline" and Time.get_ticks_msec()<until:await create_timer(.05).timeout
 ok=ok and not session.connected and session.network_role=="offline" and session.room_status=="마을에 있는 호환 버전의 방에만 참가할 수 있습니다."
 print("COOP_OLD_VERSION failures=",0 if ok else 1)
 session.queue_free();await process_frame;quit(0 if ok else 1)
