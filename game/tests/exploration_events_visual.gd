extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Events=preload("res://scripts/exploration_events.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.refresh_vision();game.hud.refresh();game.forest.update_camera();game.queue_redraw();game.map_overlay.queue_redraw();game.exploration_panel._process(0.)
	await process_frame;await RenderingServer.frame_post_draw
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/events-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	for event in Events.DEFINITIONS:
		var sim=Sim.new(7996,"forest",1);var p=sim.add_player(1,"별하");p.level=100;p.tutorial_done=true
		sim.recalculate(p);p.hp=roundi(p.max_hp*.65);p.stamina=70
		sim.add_player(2,"동료")
		Inventory.add_stack(p,"seed",2);Inventory.add_stack(p,"tool",1)
		for enemy in sim.enemies.values():enemy.hp=0
		var site=sim.map.exploration_sites.filter(func(s):return s.kind==Events.DEFINITIONS[event].kind)[0];site["event"]=event
		p.pos=site.pos+Vector2(0,1.5)
		game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);await frame()
		var panel=game.exploration_panel
		check(panel.visible and panel.heading.text==Events.DEFINITIONS[event].name,"event title visible")
		check(panel.detail.text.begins_with("각자 택 1"),"party event makes personal choice scope explicit")
		check(panel.first.visible and panel.second.visible and not panel.first.disabled and not panel.second.disabled,"two available event choices")
		for control in [panel.heading,panel.detail,panel.first,panel.second]:
			var text_width=control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
			check(text_width<=control.size.x-12,"event text fits: "+control.text)
			if control is Label:check(control.get_visible_line_count()>0,"label has visible rendered line")
		check(root.get_texture().get_image().save_png("res://../artifacts/event-"+event+"-ready.png")==OK,"capture ready event")
		p.materials.seed=0;p.materials.tool=0;p.hp=1;p.stamina=0;await frame()
		check(panel.first.disabled and not panel.first.tooltip_text.is_empty() and not panel.second.disabled,"current state blocks costly choice with reason and preserves alternative")
		check(root.get_texture().get_image().save_png("res://../artifacts/event-"+event+"-blocked.png")==OK,"capture blocked event")
		panel.second.pressed.emit();await frame()
		check(sim.exploration_claims.get(1,{}).has(site.id) and not panel.visible,"actual visible alternative grants personal reward then closes")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("EXPLORATION_EVENTS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
