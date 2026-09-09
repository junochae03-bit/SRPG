extends Node
var game
var streams={}
var pool:Array[AudioStreamPlayer]=[]
var music_players:Array[AudioStreamPlayer]=[]
var music_index=0
var music_key=""
var music_gain=0.45
var effects_gain=0.7
var current_fade:Tween
var cursors={}
var last_times={}
var last_played=""
var play_counts={}
var step_clock=0.0
var last_pos=Vector2.ZERO
var settings_path=""
var stopped=false
var playback_refs:Array[WeakRef]=[]

func track_playback(player:AudioStreamPlayer):
	pending_playbacks()
	if player.has_stream_playback():playback_refs.append(weakref(player.get_stream_playback()))

func pending_playbacks()->int:
	playback_refs=playback_refs.filter(func(reference):return reference.get_ref()!=null)
	return playback_refs.size()

func shutdown(timeout_seconds:float=3.0)->bool:
	# stop() schedules audio-thread retirement; a fixed frame/time delay does
	# not prove that AudioServer released its playback and looping WAV refs.
	stop_all()
	var deadline=Time.get_ticks_msec()+int(timeout_seconds*1000)
	while pending_playbacks()>0 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	return pending_playbacks()==0

func setup(owner_game):
	game=owner_game
	settings_path=game.session.save_directory.path_join("audio-settings.json")
	if FileAccess.file_exists(settings_path):
		var config=JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if config is Dictionary:
			music_gain=clampf(float(config.get("music",0.45)),0,1);effects_gain=clampf(float(config.get("effects",0.7)),0,1)
	var mapping=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/mapping.json"))
	for role in mapping:
		streams[role]=[]
		for path in mapping[role]:
			var stream:AudioStreamWAV=load(path)
			if role in ["title","town","field"]:
				stream=stream.duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin=0;stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
			streams[role].append(stream)
	for i in range(12):
		var player=AudioStreamPlayer.new();add_child(player);pool.append(player)
	for i in range(2):
		var player=AudioStreamPlayer.new();add_child(player);music_players.append(player)
	game.session.event_received.connect(on_event)
	game.session.action_performed.connect(on_action)
	set_music("title")

func set_gain(kind:String,value:float):
	if kind=="music":music_gain=clampf(value,0,1)
	else:effects_gain=clampf(value,0,1)
	if current_fade and current_fade.is_running():current_fade.kill()
	for i in range(music_players.size()):music_players[i].volume_db=music_volume() if i==music_index else -80
	DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	var file=FileAccess.open(settings_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"music":music_gain,"effects":effects_gain}));file.close()

func music_volume()->float:return -80.0 if game.options.has("mute") or music_gain<=0 else linear_to_db(music_gain)-19.0
func set_music(key:String):
	if stopped or key==music_key:return
	music_key=key
	if current_fade and current_fade.is_running():current_fade.kill()
	var previous=music_players[music_index]
	music_index=1-music_index
	var next=music_players[music_index];next.stream=streams[key][0];next.volume_db=-80;next.play();track_playback(next)
	current_fade=create_tween().set_parallel(true)
	current_fade.tween_property(previous,"volume_db",-80.0,1.4)
	current_fade.tween_property(next,"volume_db",music_volume(),1.4)
	current_fade.chain().tween_callback(previous.stop)

func play_sound(key:String,quiet:float=0.0):
	if stopped or not streams.has(key):return
	var now=Time.get_ticks_msec()
	if now-int(last_times.get(key,-1000))<70:return
	last_times[key]=now
	var index=int(cursors.get(key,0));cursors[key]=index+1
	var player=pool[index_for_pool()]
	player.stream=streams[key][index%streams[key].size()]
	player.volume_db=-80 if game.options.has("mute") or effects_gain<=0 else linear_to_db(effects_gain)-12+quiet
	player.pitch_scale=1.0+float(index%3-1)*0.025 if key in ["sword","axe","step"] else 1.0
	player.play();track_playback(player);last_played=key;play_counts[key]=int(play_counts.get(key,0))+1
func index_for_pool()->int:
	for i in range(pool.size()):
		if not pool[i].playing:return i
	return int(Time.get_ticks_msec()/50)%pool.size()

func on_action(kind:String):
	match kind:
		"potion":play_sound("potion")
		"equip","unequip","unequip_to","costume","avatar":play_sound("equip")
		"move_item":play_sound("move_item",-6)
		"invest","class","reset_skills","stat","reset_stats","bind_skill":play_sound("invest")
		"return":play_sound("return")
		"interact","claim_starters":play_sound("pickup")

func on_event(event:Dictionary):
	var p=game.session.state.players.get(game.session.local_id,{})
	if event.type=="notice":
		if "LEVEL UP" in event.text:play_sound("levelup",-3)
		return
	var quiet=0.0
	if event.has("pos") and not p.is_empty():quiet=-minf(20,p.pos.distance_to(event.pos)*1.4)
	match event.type:
		"monster_attack":play_sound(event.get("sound","hit_sword"),quiet-6)
		"attack":play_sound(event.get("weapon","sword"),quiet)
		"heavy":play_sound(event.get("weapon","sword") if event.get("weapon") in ["bow","staff"] else "heavy",quiet)
		"dodge":play_sound("dodge",-3)
		"nova":play_sound("nova",quiet-4)
		"skill_fx":
			var kind=event.get("fx","")
			var sound="dodge" if kind in ["rush","leap","blink"] else "bow" if kind in ["piercing","arrow_rain","volley"] else "heavy" if kind in ["blade_wave","whirlwind"] else "nova"
			if kind.begins_with("warrior_") or kind.begins_with("ranger_") or kind.begins_with("mage_"):
				sound=event.get("sound","nova")
				if kind.ends_with("heal"):sound="potion"
				elif kind.ends_with("barrier"):sound="equip"
				elif kind.ends_with("haste"):sound="invest"
				elif kind.ends_with("pull"):sound="return"
			play_sound(sound,quiet-4)
		"damage":
			if not event.get("enemy",true):play_sound("hurt")
			elif not p.is_empty():play_sound("hit_"+game.session.sim.combat.weapon_type(p),quiet-3)

func _process(delta:float):
	if stopped:return
	if not game.session.connected:set_music("title");return
	var p=game.session.state.players.get(game.session.local_id,{})
	if p.is_empty():return
	set_music("town" if game.dungeon.in_town(p.pos) else "field")
	step_clock+=delta
	if not game.session.paused and p.pos.distance_to(last_pos)>0.015 and p.dodge_time<=0 and step_clock>(0.23 if p.sprint else 0.36):
		play_sound("step",-14);step_clock=0
	last_pos=p.pos
func stop_all():
	stopped=true
	if current_fade:current_fade.kill();current_fade=null
	for player in pool+music_players:
		player.stop()
		player.stream=null
