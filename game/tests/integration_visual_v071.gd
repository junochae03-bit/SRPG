extends SceneTree
const Content=preload("res://scripts/content.gd")
const Sim=preload("res://scripts/simulation.gd")
const CraftView=preload("res://scripts/exploration_crafting_panel.gd")
const Craft=preload("res://scripts/exploration_crafting.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.hud.refresh();game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func capture(name):
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/v071-"+name+".png")==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/integration-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var config=preload("res://scripts/abyss_catalog.gd").config(12)
	var sim=Sim.new(95599,config.terrain,12);var p=sim.add_player(1,"별하");p.level=100;p.tutorial_done=true;p.highest_floor=100;p.cleared_floor=99
	game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.)
	for class_id in Content.CLASSES:
		p.class_id=class_id;sim.combat.jobs.reset(p);sim.recalculate(p)
		await frame()
		var identity=game.hud.job_resource
		for rect in identity.content_draw_rects:check(identity.content_bounds().grow(2).encloses(rect),"identity fits "+class_id+" "+str(rect))
	check(not game.hud.codex_button.visible and game.codex!=null,"book button removed; codex retained")
	p.class_id="gambler";sim.combat.jobs.reset(p);p.job_state.hand=[0,12,14,27,41];p.job_state.candidates=[2,39];p.job_state.candidate_index=0;p.job_state.dice=6;p.job_state.dice_time=3.;p.job_state.peek=7
	for i in range(2,7):
		var peer=sim.add_player(i,"동료 %d"%i);peer.pos=p.pos+Vector2(i%3+1,i/3+1);peer.revival_injury=true;sim.recalculate(peer)
	await frame();await capture("hud-gambler")
	# The natural wall dressing remains outside walkable terrain and the
	# six-player silhouette remains visible during actual overlapping renders.
	for peer in sim.players.values():peer.pos=p.pos+Vector2(.08*peer.id,.08*peer.id)
	await capture("party-overlap")
	var dressing=preload("res://scripts/cave_dressing_v071.gd").new();dressing.rebuild(sim.map)
	for support in dressing.supports(sim.map):check(not sim.map.floor_cells.has(Vector2i(support.pos)) and support.pos.distance_to(sim.map.spawn)>=7.,"human trace never blocks a passage or spawn")
	check(dressing.supports(sim.map).size()<=2,"human trace density capped")
	var ecology=preload("res://scripts/monster_ecology_v071.gd")
	var art=preload("res://scripts/monster_ecology_art_v071.gd")
	for monster in ecology.data().monsters:
		for phase in [0,1,2,3]:
			var specimen={"kind":monster,"hp":1,"windup":1. if phase==1 else 0.,"attack_motion":.1 if phase>=2 else 0.,"attack_motion_duration":1.,"attack_impact_time":.1 if phase==2 else 0.}
			check(not art.frame(specimen).is_empty() and art.pose_index(specimen)==phase,"approved runtime monster pose "+monster+str(phase))
	check(game.hud.expedition.party.rows.filter(func(row):return row.visible).size()==5,"five peers visible")
	check(game.hud.expedition.party.rows[0].buffs.any(func(b):return b.key=="revival_injury"),"persistent injury visible")
	game.hud.expedition.tabs[0].pressed.emit();await frame();check(game.skill_tree.visible,"stats tab opens details")
	game.skill_tree.hide();game.hud.expedition.tabs[1].pressed.emit();await frame();check(game.skill_tree.visible,"skills tab opens map");await capture("skills")
	var target=game.skill_tree.path_button
	var mouse=InputEventMouseMotion.new();mouse.position=target.get_global_transform_with_canvas()* (target.size*.5);root.push_input(mouse,true)
	await frame();await capture("skills-hover")
	check(target.is_hovered(),"actual pointer hovers skill path button")
	check(target.get_meta("rpg_frame").modulate==Color("514653"),"hover keeps dark textured surface")
	check(target.get_theme_color("font_hover_color")==Color("eee1c9") and target.get_theme_color("font_hover_pressed_color")==Color("eee1c9"),"hover and pressed labels retain ivory contrast")
	var popup=game.skill_tree.filter_picker.get_popup()
	var picker=game.skill_tree.filter_picker
	var click=InputEventMouseButton.new();click.position=picker.get_global_transform_with_canvas()*(picker.size*.5);click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	root.push_input(click,true);click=click.duplicate();click.pressed=false;root.push_input(click,true)
	await frame();check(popup.visible,"actual pointer opens skill filter")
	popup.set_focused_item(1);await frame();await capture("skills-filter")
	check(popup.get_theme_stylebox("hover").bg_color==Color("514653"),"dropdown highlight stays dark")
	check(popup.get_theme_color("font_hover_color")==Color("eee1c9"),"dropdown highlight retains ivory text")
	var paper=popup.get_meta("thin_paper_background").get_child(0)
	check(paper.modulate==Color("343039"),"dropdown paper matches dark skill panel")
	popup.hide()
	game.skill_tree.hide()
	game.hud.expedition.tabs[2].pressed.emit();await frame();check(game.bag.visible,"bag tab opens inventory")
	game.bag.show_stats();await frame();check(game.bag.stats_values.size()==20,"all twenty stats have rows");await capture("stats");game.bag.hide()
	var town=Sim.new(841,"town");p=town.add_player(1,"별하");p.level=100;p.class_id="warrior";p.gold=1000000;p.tutorial_done=true
	for key in Craft.Data.materials():Craft.Inventory.add_stack(p,key,99)
	game.session.sim=town;game.session.refresh();game.on_entered();p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.smith.pos;await frame();game.town_panel.open("smith");game.town_panel.choose("craft_equipment");await frame()
	var view=game.town_panel.body.get_children().filter(func(child):return child is CraftView)[0]
	check(view is CraftView,"smith opens crafting panel")
	view.selected=Craft.Data.recipes().keys().filter(func(key):return Craft.Data.recipes()[key].job=="warrior" and int(Craft.Data.recipes()[key].rarity)==4)[0];view.rebuild();await frame();await capture("crafting")
	check(view.confirm!=null and not view.confirm.disabled,"legendary craft can execute with raid materials")
	view.confirm.pressed.emit();await frame();check(p.inventory.size()==1 and p.inventory[0].rarity==4,"actual smith button crafts legendary gear")
	game.town_panel.hide();p.revival_injury=true;p.revival_weakness=true;town.recalculate(p);p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.church.pos;await frame();game.town_panel.open("church");await frame();await capture("church")
	check(game.town_panel.confirm_button!=null and not game.town_panel.confirm_button.disabled,"church treatment reachable")
	game.town_panel.confirm_button.pressed.emit();await frame();check(not p.revival_weakness and p.revival_injury,"church removes only weakness")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("INTEGRATION_VISUAL_V071 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
