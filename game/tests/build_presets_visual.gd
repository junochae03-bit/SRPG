extends SceneTree
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/presets-visual/"+str(Time.get_ticks_usec()));root.add_child(game)
	await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var p=game.session.sim.players[1];p.level=100;p.class_id="runesword";p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={};p.tutorial_done=true;game.session.sim.map.zone="town";game.session.sim.recalculate(p);game.session.refresh()
	game.toggle_skills();var panel=load("res://scripts/build_preset_panel.gd").new();game.skill_tree.add_child(panel);panel.setup(game.skill_tree)
	check(panel.quote.ok and not panel.commit.disabled,"visible usable preview")
	check(panel.picker.item_count==5 and panel.quote.loadout.size()==6,"class choices and six skills")
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/build-presets.png")==OK,"native preview capture")
	var loadout=panel.quote.player.skill_loadout.duplicate(true);panel.commit.pressed.emit();await process_frame
	check(p.skill_loadout==loadout and game.skill_tree.loadout_strip.visible,"button applies real loadout")
	var waiting=load("res://scripts/build_preset_panel.gd").new();game.skill_tree.add_child(waiting);waiting.setup(game.skill_tree)
	waiting.serial=71;waiting.picker.disabled=true;waiting.commit.disabled=true
	game.session.connected=false;game.session.status_changed.emit("연결 종료")
	await process_frame
	check(not is_instance_valid(waiting),"disconnect removes pending preview instead of retaining locked panel")
	game.session.connected=true
	var reopened=load("res://scripts/build_preset_panel.gd").new();game.skill_tree.add_child(reopened);reopened.setup(game.skill_tree)
	check(reopened.serial==-1 and not reopened.picker.disabled,"new session preview has no stale request lock")
	reopened.close();await process_frame
	check(preload("res://scripts/icon_library.gd").audit().unknown_requests.is_empty(),"semantic icons resolved")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("BUILD_PRESETS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
