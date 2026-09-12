extends SceneTree
## Uses actual AudioStreamPlayers; mute only changes volume, never test coverage.
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	for muted in [true,false]:
		var game=load("res://main.tscn").instantiate()
		if muted:game.options.mute=true
		game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/audio-shutdown-v04/"+str(Time.get_ticks_usec()))
		root.add_child(game);game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
		var director=game.audio_director;director.set_process(false)
		await process_frame
		var label="muted" if muted else "audible"
		check(director.pending_playbacks()==1,"real title playback "+label)
		check((director.music_volume()<=-80)==muted,"music volume follows mute without skipping playback "+label)
		var title=director.music_players[director.music_index]
		var initial_position=title.get_playback_position()
		var mix_deadline=Time.get_ticks_msec()+1000
		while title.get_playback_position()<=initial_position and Time.get_ticks_msec()<mix_deadline:await process_frame
		check(title.playing and title.get_playback_position()>initial_position,"actual title playback advances %s (%s: %.4f → %.4f)"%[label,AudioServer.get_driver_name(),initial_position,title.get_playback_position()])
		for weapon in ["sword","axe","bow","staff"]:
			director.last_times.clear()
			director.on_event({"type":"damage","enemy":true,"weapon":weapon,"owner":2})
			check(director.last_played=="hit_"+weapon,"remote impact uses source weapon "+weapon+" "+label)
			var sounds=int(director.play_counts["hit_"+weapon])
			for i in 30:director.on_event({"type":"damage","enemy":true,"weapon":weapon,"owner":2})
			check(int(director.play_counts["hit_"+weapon])==sounds,"same-frame area hits do not stack thirty sounds "+weapon)
		game.session.sim=preload("res://scripts/simulation.gd").new(115,"town",1)
		game.session.state.players={1:game.session.sim.add_player(1,"검사"),2:game.session.sim.add_player(2,"궁수",{"class_id":"ranger"})}
		director.last_times.clear();director.on_event({"type":"damage","enemy":true,"owner":2})
		check(director.last_played=="hit_bow","legacy event falls back to actual source actor "+label)
		if not muted:
			var remote=director.pool.filter(func(player):return player.playing and player.stream==director.streams.hit_bow[(director.cursors.hit_bow-1)%director.streams.hit_bow.size()]).back()
			var remote_volume=remote.volume_db
			director.last_times.clear();director.on_event({"type":"damage","enemy":true,"weapon":"axe","owner":1})
			var local=director.pool.filter(func(player):return player.playing and player.stream==director.streams.hit_axe[(director.cursors.hit_axe-1)%director.streams.hit_axe.size()]).back()
			check(is_equal_approx(local.volume_db-remote_volume,4.),"remote impact four decibels below local")
		game.session.state.players={}
		for action in ["mana_potion","power_potion"]:
			director.last_times.clear();director.on_action(action)
			check(director.last_played=="potion","new potion audio "+action)
		director.set_music("town")
		var town=director.music_players[director.music_index]
		check(town.playing and title.playing,"incoming and outgoing music overlap during fade "+label)
		await create_timer(1.5).timeout
		check(town.playing and not title.playing,"completed fade preserves incoming music and retires old music "+label)
		check(is_equal_approx(town.volume_db,director.music_volume()),"completed fade reaches intended gain "+label)
		# Replacing an in-progress fade must not lose retirement tracking.
		director.set_music("field");director.set_music("title")
		director.play_sound("sword");director.play_sound("heavy")
		var count=director.pending_playbacks()
		check(count>=3,"interrupted music and live effects are tracked "+label)
		var alive=director.playback_refs.duplicate()
		check(await director.shutdown(),"shutdown waits for actual AudioServer retirement "+label)
		check(alive.all(func(reference):return reference.get_ref()==null),"all pre-shutdown weak playback references expired "+label)
		check(director.current_fade==null and director.pending_playbacks()==0,"no tween or playback remains "+label)
		check(director.music_players.all(func(player):return player.stream==null and not player.playing),"music stream ownership released "+label)
		check(director.pool.all(func(player):return player.stream==null and not player.playing),"effect stream ownership released "+label)
		director.set_music("town");director.play_sound("bow")
		check(director.pending_playbacks()==0,"late callbacks cannot restart shutdown audio "+label)
		check(await director.shutdown(),"idempotent shutdown "+label)
		director=null;title=null;town=null;alive.clear();game.queue_free();game=null
		await process_frame;await process_frame
	print("AUDIO_SHUTDOWN_V04_TESTS checks=",checks," failures=",failures.size()," driver=",AudioServer.get_driver_name());quit(0 if failures.is_empty() else 1)
