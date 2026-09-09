extends SceneTree
const Content=preload("res://scripts/content.gd")
const GatArt=preload("res://scripts/gat_art.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/appearance-v041/"+str(Time.get_ticks_usec()));game.join_game()
	var p=session.sim.players[1]
	check(p.costume=="none" and p.avatar=="auto","new character uses GAT base")
	check(Content.AVATARS.size()==37,"37 supplied character IDs remain registered")
	check(game.hud.bag_button.text=="" and game.hud.growth_button.text=="","top actions are sprite buttons")
	check(game.hud.get_children().filter(func(c):return c is Button and "메뉴" in c.text).is_empty(),"HUD menu button removed")
	game.hud.bag_button.pressed.emit();check(game.bag.visible and session.paused,"bag sprite opens paused inventory")
	game.hud.bag_button.pressed.emit();game.hud.growth_button.pressed.emit();check(game.skill_tree.visible and session.paused,"book sprite opens growth")
	game.hud.growth_button.pressed.emit();var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;game._unhandled_input(escape)
	check(game.help_panel.visible and session.paused,"Esc retains menu access");game.continue_game();game.toggle_bag()
	for class_id in Content.CLASSES:
		p.class_id=class_id;Content.normalize_appearance(p);session.sim.recalculate(p);session.refresh();game.bag.refresh(true)
		check(game.bag.avatar_keys==Content.avatar_options(class_id) and game.bag.costume_keys==Content.costume_options(class_id),"class-filtered indexes agree "+class_id)
		for key in game.bag.avatar_keys:
			p.motion_time=0
			game.bag.avatar_picker.item_selected.emit(game.bag.avatar_keys.find(key))
			check(p.avatar==key and p.costume=="none","allowed base selector applies "+class_id+":"+key)
			check(game.bag.portrait.texture==GatArt.frame(p,0).texture and game.hud.portrait==GatArt.portrait(p),"base previews agree "+class_id+":"+key)
			if key!="auto":
				p.motion_time=.25;p.motion_duration=.5
				check(GatArt.frame(p,0).index==(6 if preload("res://scripts/combat_sprite_art.gd").AVATARS.has(key) else 3),"attack pose selected "+key)
		p.motion_time=0
		var base_avatar=p.avatar
		for key in game.bag.costume_keys:
			game.bag.costume_picker.item_selected.emit(game.bag.costume_keys.find(key))
			check(p.costume==key and p.avatar==base_avatar,"allowed costume preserves base "+class_id+":"+key)
			if key!="none" and not Content.gat_appearance(p):check(game.bag.portrait.texture==game.textures[Content.costume_role(p)].idle[0],"legacy costume uses original sprite "+key)
		var blocked=Content.AVATARS.keys().filter(func(key):return not game.bag.avatar_keys.has(key))
		if not blocked.is_empty():
			var before_avatar=p.avatar
			check(not session.act("avatar",blocked[0]) and p.avatar==before_avatar,"hidden base appearance also rejected by session "+class_id)
	var avatar=p.avatar
	session.act("costume","none");session.save_game();var saved=session.parse_save(session.save_path())
	check(saved.avatar==avatar and saved.costume=="none" and saved.schema_version==7,"base selection persisted in v5")
	session.disconnect_game();session.start_game("복원",1);check(session.sim.players[1].avatar==avatar,"base selection restored")
	var old=saved.duplicate(true);old.schema_version=3;old.costume="witch";old.erase("avatar");old.erase("legacy_costume")
	var migrated=session.sim.add_player(2,"이행",old)
	check(migrated.costume=="none" and migrated.legacy_costume=="witch" and migrated.avatar=="auto","legacy skin becomes optional while GAT is displayed")
	check(migrated.level==old.level and migrated.inventory==old.inventory and migrated.skill_ranks==old.skill_ranks,"appearance migration preserves gameplay")
	game.stop_audio();await create_timer(.5).timeout;session.disconnect_game();game.queue_free();await process_frame
	print("APPEARANCE_V041_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
