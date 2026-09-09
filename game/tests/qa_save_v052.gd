extends SceneTree
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func check_write_boundaries(session,folder:String):
	var data=session.sim.persistent(1);data.world_seed=session.world_seed
	for suffix in [".tmp",".bak",""]:
		var path=folder.path_join("경계-"+suffix.trim_prefix(".")+".json")
		if not suffix.is_empty():check(session.write_save(data,path),"경계 검증의 기존 기록 저장")
		var previous=FileAccess.get_file_as_bytes(path) if not suffix.is_empty() else PackedByteArray()
		var occupied=path+suffix
		check(DirAccess.make_dir_absolute(occupied)==OK,"저장 경로 충돌 재현")
		data.gold+=1
		check(not session.write_save(data,path) and not session.last_save_error.is_empty(),"임시·백업·최종 파일 충돌 거부")
		if not suffix.is_empty():check(FileAccess.get_file_as_bytes(path)==previous,"쓰기 실패 시 기존 기록 보존")
		check(DirAccess.remove_absolute(occupied)==OK,"검증용 빈 폴더 해제")
		check(session.write_save(data,path) and session.parse_save(path).gold==data.gold,"경로 복구 후 같은 저장 정상 완료")
func run():
	var folder=ProjectSettings.globalize_path("res://../runtime/qa-save-v052/"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var blocker=folder.path_join("blocked-parent");var file=FileAccess.open(blocker,FileAccess.WRITE);file.store_string("not a directory");file.close()
	var game=load("res://main.tscn").instantiate();game.options={"mute":true,"save-dir":folder};root.add_child(game);await process_frame
	game.set_physics_process(false);game.set_process(false);var session=game.session;session.set_physics_process(false)
	session.start_game("저장 검증",1);var p=session.sim.players[1]
	check_write_boundaries(session,folder)
	var messages=[];session.status_changed.connect(func(message):messages.append(message))
	var original=session.parse_save(session.save_path());check(original!=null,"initial save reads")
	p.gold+=7;session.sim.dirty[1]=true;session.save_directory=blocker.path_join("saves")
	session.flush_events();check(session.save_failed and session.sim.dirty.has(1),"failed auto-save retains dirty state")
	check(not session.disconnect_game() and session.connected and session.sim.players[1]==p,"failed disconnect keeps live character")
	check(not messages.any(func(message):return message.begins_with("저장했습니다")),"no false success message")
	check(session.parse_save(folder.path_join("slot-1.json")).gold==original.gold,"failed save preserves previous disk record")
	session.paused=true;session.save_directory=folder;session._physics_process(1.1)
	check(not session.save_failed and session.sim.dirty.is_empty() and session.connected and session.paused,"paused auto-retry succeeds without closing session")
	check(session.parse_save(session.save_path()).gold==p.gold,"recovered disk includes unsaved change")
	p.tutorial_kills=5;p.tutorial_done=false;p.quest_done=false;session.save_game()
	var old_sim=session.sim;var old_seed=session.world_seed;var old_gold=p.gold
	session.save_directory=blocker.path_join("saves")
	check(not session.travel("town"),"failed map save rejects transition")
	check(session.sim==old_sim and session.world_seed==old_seed and not p.tutorial_done and p.gold==old_gold,"map, seed and tutorial reward remain atomic")
	session.save_directory=folder
	check(session.travel("town"),"map transition retries after path recovery")
	p=session.sim.players[1]
	check(p.tutorial_done and p.gold==old_gold+100 and session.sim.map.zone=="town","arrival grants exactly one tutorial reward")
	check(session.travel("town") and session.sim.players[1].gold==old_gold+100,"repeat travel does not duplicate reward")
	p=session.sim.players[1];p.gold+=11;session.sim.dirty[1]=true;session.save_directory=blocker.path_join("saves")
	game.settings_panel.open();game.settings_panel.return_to_title()
	check(session.connected and game.settings_panel.visible and game.settings_panel.status.text.contains("저장 실패"),"settings stays open with truthful retry feedback")
	game.settings_panel.hide();game.help_panel.open();game.help_panel.return_to_title()
	check(session.connected and game.help_panel.visible and game.help_panel.status.text.contains("저장 실패"),"keyboard title action retains session on failure")
	game.help_panel.hide();session.paused=false;await game.finish_run()
	check(not game.quitting and session.connected and game.settings_panel.visible and session.sim.dirty.has(1),"window close does not discard unsaved character")
	game.settings_panel.close();check(not session.paused and session.connected,"종료 실패 설정을 닫으면 기존 플레이로 복귀")
	game.settings_panel.open()
	session.save_directory=folder;game.settings_panel.return_to_title()
	check(not session.connected and not game.settings_panel.visible and session.parse_save(folder.path_join("slot-1.json")).gold==p.gold,"same title action completes after recovery")
	game.stop_audio();game.queue_free();await process_frame;await process_frame
	print("QA_SAVE_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
