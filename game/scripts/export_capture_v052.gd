extends RefCounted
# Optional release-verification controls. Save fixtures come from the isolated
# --save-dir; no stats, items, currency or learned skills are created here.
const World=preload("res://scripts/world_catalog.gd")
const Training=preload("res://scripts/training_ground.gd")
const TrainingArt=preload("res://scripts/training_art.gd")
const Inventory=preload("res://scripts/inventory_model.gd")

static func prepare(game):
	if game.options.has("show-settings"):
		var page=str(game.options.get("settings-page","sound"))
		if game.settings_panel.pages.has(page):game.settings_panel.select_page(page)
		if game.options.has("settings-keys"):game.settings_panel.key_button.pressed.emit()
	if game.bag.visible and game.options.has("bag-select"):
		game.bag.select_item(str(game.options["bag-select"]))
	# Moving a capture fixture is permitted only for an explicitly isolated save.
	if not game.session.connected or not game.options.has("save-dir"):return
	var sim=game.session.sim
	if sim.map.zone!="town":return
	var p=sim.players[game.session.local_id]
	var relocated=false
	if game.options.has("show-training"):
		game.set_meta("export_training_before",sim.persistent(p.id).duplicate(true))
		p.pos=Training.POSITION+Vector2(-3,.5);p.dir=Vector2.ZERO;p.aim=Vector2.RIGHT
		game.session.paused=false;game.session.refresh()
		var attacked=game.session.act("attack")
		var cast=game.session.act("skill_q")
		sim.tick(.12);game.session.flush_events();game.session.refresh()
		game.set_meta("export_training_actions",{"attack":attacked,"skill_q":cast})
		relocated=true
	if game.options.has("show-facility"):
		var key=str(game.options["show-facility"])
		if World.FACILITIES.has(key):
			if not (key=="training" and game.options.has("show-training")):
				var target=World.resident_pos(key) if World.RESIDENTS.has(key) else World.FACILITIES[key].pos
				for offset in [Vector2(.5,1.),Vector2(-.5,1.),Vector2(1.,0.),Vector2.ZERO]:
					if sim.map.walkable(target+offset) and World.nearest(target+offset)==key:p.pos=target+offset;break
			p.dir=Vector2.ZERO;game.session.refresh();game.town_panel.open(key)
			if key=="costume" and game.options.has("wardrobe-select"):
				game.town_panel.wardrobe_view.choose(str(game.options["wardrobe-select"]))
			relocated=true
	if relocated:
		game.smooth_positions.clear();game.update_battle_camera(p,0.,true);game.forest.update_camera(0.)
		game.queue_redraw();game.map_overlay.queue_redraw()

static func packed_files(path:String)->Array:
	var result=[]
	if not DirAccess.dir_exists_absolute(path):return result
	for name in DirAccess.get_files_at(path):result.append(path.path_join(name))
	for name in DirAccess.get_directories_at(path):result.append_array(packed_files(path.path_join(name)))
	return result

static func evidence(game)->Dictionary:
	var result={"settings":{"visible":game.settings_panel.is_visible_in_tree(),"page":game.settings_panel.selected_page,"pages":game.settings_panel.pages.keys(),"keys_button":game.settings_panel.key_button.text,"keyboard":game.help_panel.is_visible_in_tree(),"keyboard_returns_to_settings":game.help_panel.return_panel==game.settings_panel},"inventory":{"visible":game.bag.is_visible_in_tree(),"capacity":Inventory.CAPACITY,"capacity_label":game.bag.capacity.text,"grid_size":[Inventory.WIDTH,Inventory.HEIGHT],"scroll":game.bag.grid_scroll.scroll_vertical,"comparison_visible":game.bag.comparison_panel.is_visible_in_tree(),"selected":game.bag.comparison_selected_id,"equipped":game.bag.comparison_current_id,"rows":game.bag.comparison_rows.duplicate(true),"current_name":game.bag.comparison_current_name.text},"facility":{"visible":game.town_panel.is_visible_in_tree(),"id":game.town_panel.facility},"packed_resources":{},"excluded_packs":{}}
	for path in [TrainingArt.SOURCE,"res://scripts/training_ground.gd","res://scripts/skill_reach.gd","res://scripts/monster_aim.gd","res://scripts/settings_panel.gd","res://scripts/town_operations.gd"]:
		result.packed_resources[path]=ResourceLoader.exists(path)
	for path in ["res://assets/costume_v06","res://assets/skill_motions_v06"]:result.excluded_packs[path]=packed_files(path)
	if not game.session.connected:return result
	var sim=game.session.sim;var p=sim.players[game.session.local_id]
	result["persistent"]=sim.persistent(p.id)
	result.facility["nearest"]=World.nearest(p.pos)
	result.facility["walkable"]=sim.map.walkable(p.pos)
	if game.town_panel.is_visible_in_tree() and game.town_panel.facility=="costume":
		var view=game.town_panel.wardrobe_view
		result.facility["wardrobe"]={"visible":view.is_visible_in_tree(),"selected":game.town_panel.wardrobe_selection,"name":view.selected_name.text,"price":view.price_label.text,"action":view.action_button.text,"cards":view.cards.keys(),"renaming":view.name_field.is_visible_in_tree()}
	var training_enemies=sim.enemies.values().filter(func(e):return e.get("training",false))
	result["training"]={"count":training_enemies.size(),"stats":Training.summary(p),"drops":sim.drops.size(),"before":game.get_meta("export_training_before",{}),"actions":game.get_meta("export_training_actions",{}),"rendered":false}
	if not training_enemies.is_empty():
		var e=training_enemies[0];result.training["enemy"]={"name":e.name,"hp":e.hp,"max_hp":e.max_hp,"rewarded":e.get("rewarded",false),"raid":e.raid,"guardian":e.guardian,"position":[e.pos.x,e.pos.y],"stagger":e.stagger.duplicate(true)}
		result.training.rendered=game.monster_aim_frames.has(e.id)
		if result.training.rendered:
			var drawn:Dictionary=game.monster_aim_frames[e.id];var frame=TrainingArt.texture()
			result.training["drawn_height"]=drawn.rect.size.y
			result.training["texture_source"]=frame.atlas.resource_path
			result.training["texture_size"]=[frame.get_width(),frame.get_height()]
	return result
