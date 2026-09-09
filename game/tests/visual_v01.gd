extends SceneTree
const World=preload("res://scripts/world_catalog.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
func _initialize():
	run.call_deferred()
func capture(name:String):
	await create_timer(.25).timeout;await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+name+".png"))==OK);print("CAPTURE ",name)
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/visual-v01/"+str(Time.get_ticks_usec()));game.join_game();session.sim.players[1].tutorial_done=true;session.travel("town");session.set_physics_process(false);game.set_physics_process(false)
	var p=session.sim.players[1];p.level=30;p.gold=1765;p.materials={"seed":32,"ore":16,"essence":4};session.act("claim_starters")
	for type in Equipment.BASES:Inventory.add_gear(p,Equipment.make(type,2,2 if type in ["sword","head"] else 1,"sample-"+type,"vigor" if type=="chest" else "focus" if type=="sword" else "none"))
	session.sim.recalculate(p);session.refresh();game.on_entered();game.camera_pos=preload("res://scripts/dungeon.gd").iso(p.pos)
	game.toggle_bag();game.bag.select_item("sample-sword");await capture("inventory-v01");game.toggle_bag()
	game.toggle_skills();p.skill_ranks={"blade":1,"heavy_training":1,"blade_wave":1};session.refresh();game.skill_tree.choice="blade_wave";game.skill_tree.refresh(true);await capture("skills-level1-v01")
	game.skill_tree.invest.pressed.emit();game.skill_tree.invest.pressed.emit();await capture("skills-level3-v01")
	game.skill_tree.search.text="회복";game.skill_tree.search.text_changed.emit("회복");await capture("skills-search-v01");game.toggle_skills()
	for facility in ["shop","smith","alchemy","guild","inn","portal"]:
		p.pos=World.FACILITIES[facility].pos;session.refresh();session.act("interact")
		if facility in World.RESIDENTS:
			assert(game.npc_dialogue.visible);game.npc_dialogue.service_button.pressed.emit()
		assert(game.town_panel.visible and game.town_panel.facility==facility)
		if facility=="shop":game.town_panel.choose("buy",{"index":3})
		elif facility=="smith":game.town_panel.choose("upgrade",{"item":"sample-sword"})
		elif facility=="alchemy":game.town_panel.choose("essence")
		elif facility=="inn":p.hp=45;p.stamina=20;game.town_panel.refresh()
		await capture("service-"+facility+"-v01")
		if facility=="smith":game.town_panel.confirm_button.pressed.emit();await capture("service-smith-result-v01")
		game.town_panel.close()
	game.stop_audio();await create_timer(.5).timeout;session.disconnect_game();game.queue_free();await process_frame;print("VISUAL_V01_PASS");quit()
