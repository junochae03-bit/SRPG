extends SceneTree
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,name:String):
	checks+=1
	if not ok:failures.append(name);push_error(name)
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.options.mute=true
	var session=game.session
	session.save_directory=ProjectSettings.globalize_path("res://../runtime/expansion-ui/"+str(Time.get_ticks_usec()))
	game.audio_director.settings_path=session.save_directory.path_join("audio-settings.json")
	game.join_game()
	session.sim.players[1].tutorial_done=true;session.travel("town")
	var p=session.sim.players[1];p.level=8;session.sim.recalculate(p);session.refresh()
	game.toggle_skills()
	check(session.paused and game.skill_tree.visible,"skill tree pauses world")
	check(game.skill_tree.nodes.size()==95,"class has fifty original and45 specialization nodes")
	game.skill_tree.choice="blade";game.skill_tree.refresh(true)
	var before=session.sim.damage_for(p)
	game.skill_tree.invest.pressed.emit()
	check(p.skill_ranks.blade==1 and session.sim.damage_for(p)==before+2,"skill investment UI changes actual damage")
	check(game.audio_director.last_played=="invest","investment triggers recovered audio")
	game.skill_tree.class_picker.item_selected.emit(Content.CLASSES.keys().find("ranger"))
	check(p.class_id=="warrior","class picker previews without changing character")
	game.skill_tree.class_commit.pressed.emit()
	check(p.class_id=="ranger" and p.skill_ranks.is_empty(),"class button changes role and refunds")
	check(game.hud.circles.skill_q.caption.contains("미장착"),"HUD skill caption follows class")
	game.toggle_skills();game.toggle_bag()
	check(game.bag.costume_keys==Content.costume_options(p.class_id),"costume picker follows changed class")
	for id in game.bag.costume_keys:
		game.bag.costume_picker.item_selected.emit(game.bag.costume_keys.find(id))
		check(p.costume==id,"costume picker applies "+id)
		if id!="none" and not Content.gat_appearance(p):check(game.bag.portrait.texture==game.textures[Content.costume_role(p)].idle[0],"costume preview uses matching sprite "+id)
	var chosen_costume=p.costume
	game.toggle_bag()
	session.act("claim_starters")
	session.travel("forest");p=session.sim.players[1]
	p.pos=Vector2(session.sim.map.rooms[1]);p.stamina=100
	session.sim.enemies.clear();session.refresh()
	p.level=20;session.sim.recalculate(p)
	for node in Content.SKILLS.ranger:session.act("invest",node.id)
	for action in ["skill_f","skill_v","skill_c"]:
		p.pos=Vector2(session.sim.map.rooms[1]);p.stamina=p.max_stamina;p[action+"_cd"]=0
		game.audio_director.last_times.clear();session.refresh()
		game.action_buttons[action].pressed.emit()
		check(p[action+"_cd"]>0,"new HUD button activates learned skill "+action)
		check(game.hud.circles[action].cooldown>0 and game.hud.circles[action].caption==Content.active_node(p,action).name,"new HUD shows actual cooldown and skill name "+action)
		check(game.audio_director.last_played==("dodge" if action=="skill_c" else "bow"),"new skill maps recovered effect sound "+action)
	game.toggle_skills();var frozen=p.skill_f_cd;session._physics_process(.5)
	check(not session.act("skill_f") and p.skill_f_cd==frozen,"skill tree pauses new cooldowns and prevents cast")
	game.toggle_skills();p.pos=Vector2(session.sim.map.rooms[1]);p.stamina=p.max_stamina
	for type in Content.WEAPONS:
		var item={"id":"audio-"+type,"name":"검증 무기","category":"weapon","slot":"weapon","weapon_type":type,"bonus":0,"rarity":0};preload("res://scripts/inventory_model.gd").add_gear(p,item)
		session.act("equip",item.id);p.attack_cd=0
		session.act("attack")
		check(game.audio_director.play_counts.get(type,0)>0,"weapon attack maps audio "+type)
	var event=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.pressed=true
	# The preceding retreat uses the same sample; allow its intentional 70 ms audio gate to expire.
	while Time.get_ticks_msec()-int(game.audio_director.last_times.get("dodge",0))<75:await process_frame
	game._unhandled_input(event)
	check(p.dodge_time>0 and game.audio_director.last_played=="dodge","Space triggers dodge and roll audio")
	p.dodge_time=0;p.attack_cd=0;p.stamina=100
	var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_RIGHT;down.pressed=true
	game._unhandled_input(down);check(p.charge_time==0,"RMB begins charging")
	session.sim.tick(0.5)
	down.pressed=false;game._input(down)
	check(p.charge_time<0 and p.attack_cd>0,"RMB release completes charge even over UI")
	game.audio_director._process(0.01)
	check(game.audio_director.music_key=="field","field selects forest music")
	p.pos=session.sim.map.spawn;session.refresh();game.audio_director._process(0.01)
	check(game.audio_director.music_key=="town","camp changes BGM")
	game.audio_director.set_gain("music",0.25);game.audio_director.set_gain("effects",0.55)
	var volume=JSON.parse_string(FileAccess.get_file_as_string(game.audio_director.settings_path))
	check(is_equal_approx(volume.music,0.25) and is_equal_approx(volume.effects,0.55),"separate sound settings persist")
	session.save_game();var saved=session.parse_save(session.save_path())
	check(saved.costume==chosen_costume and Content.appearance_allowed(saved.class_id,saved.avatar,saved.costume) and saved.class_id=="ranger","allowed costume and class persist")
	session.disconnect_game();game.audio_director._process(0.01)
	check(game.audio_director.music_key=="title","return to title changes BGM")
	game.stop_audio();await create_timer(0.5).timeout;game.queue_free();await process_frame
	print("EXPANSION_UI_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
