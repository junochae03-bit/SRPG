extends SceneTree
const Content=preload("res://scripts/content.gd")
const Jobs=preload("res://scripts/job_balance.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Active=preload("res://scripts/active_skills.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Keys=preload("res://scripts/key_bindings.gd")
const Gat=preload("res://scripts/gat_art.gd")
var checks=0
var failures=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await frame();await frame()
	var image=root.get_texture().get_image();check(image.get_size()==Vector2i(1920,1080),"FullHD "+name)
	check(image.save_png(ProjectSettings.globalize_path("res://../artifacts/performance-ui-v05-"+name+".png"))==OK,"capture "+name)
func reference_cooldowns(hud,p:Dictionary,label:String):
	for action in Content.ACTIONS:
		var node=Content.active_node(p,action);var rank=int(p.skill_ranks.get(node.get("id",""),0))
		if rank==0:continue
		var profile=Jobs.profile(p,node,rank,game.session.sim.damage_for(p),p.max_hp,p.skill_ranks.get(node.id+"_upgrade",0)>0) if Content.job(p) else Scaling.profile(node,rank,Active.bonuses(p))
		check(is_equal_approx(hud.circles[action].max_cooldown,float(profile.cooldown)),"uncached reference cooldown "+label+" "+action)
		check(hud.circles[action].picture!=null,"actual action art "+label+" "+action)
func changed(hud,p:Dictionary,label:String):
	var previous=hud.metadata_rebuilds;game.session.refresh();hud.refresh()
	check(hud.metadata_rebuilds==previous+1,"one metadata invalidation "+label);reference_cooldowns(hud,p,label)
func key(code:int,unicode:int=0):
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.unicode=unicode;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func popup_checks(picker:OptionButton,label:String):
	var popup=picker.get_popup();check(popup.has_meta("thin_paper_popup"),"shared thin popup "+label)
	var style=popup.get_theme_stylebox("panel");check(style is StyleBoxEmpty,"no ornate stretched style behind list "+label)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:check(style.get_content_margin(side)>=14,"readable popup inset "+label)
	check(popup.max_size.y==440,"long list scroll height "+label)
	var paper=popup.get_meta("thin_paper_background");var rim=paper.get_child(0)
	check(rim.patch_margin_left*rim.scale.x<=4.01 and rim.patch_margin_left==128,"entire corner flourish fits four pixels "+label)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/performance-ui-v05/"+str(Time.get_ticks_usec()));game.keybindings.bindings=Keys.DEFAULTS.duplicate()
	game.join_game();var local=game.session;local.set_physics_process(false);game.set_physics_process(false)
	var p=local.sim.players[1];p.tutorial_done=true;p.level=100;local.travel("town");p=local.sim.players[1]
	var hud=game.hud
	for job in Content.CLASSES:
		p.class_id=job;p.avatar="auto";p.costume="none";p.skill_ranks.clear();p.skill_loadout.clear();p.constellation_allocations.clear()
		local.sim.combat.jobs.reset(p);var actives=Content.SKILLS[job].filter(func(n):return n.effect=="active")
		for i in range(mini(6,actives.size())):p.skill_ranks[actives[i].id]=3;p.skill_loadout[Content.ACTIONS[i]]=actives[i].id
		local.sim.recalculate(p);local.refresh();hud.refresh();reference_cooldowns(hud,p,job)
		var rebuilds=hud.metadata_rebuilds;var evaluations=hud.profile_evaluations
		for i in range(8):p.hp=maxi(1,p.max_hp-i);p.stamina=maxf(0,p.max_stamina-i);p.potion_cd=float(i)*.1;p.charge_time=float(i)*.05;local.refresh();hud.refresh()
		check(hud.metadata_rebuilds==rebuilds and hud.profile_evaluations==evaluations,"live health/stamina/cooldown does not rebuild profiles "+job)
		check(hud.hp_label.text=="%d / %d"%[p.hp,p.max_hp] and is_equal_approx(hud.circles.potion.cooldown,p.potion_cd),"live status still updates "+job)
		for circle in hud.circles.values():check(Rect2(Vector2.ZERO,circle.size).encloses(circle.picture_rect()),"icon inside action target "+job)
	p.class_id="runesword";p.avatar="auto";p.costume="none";p.skill_ranks.clear();p.skill_loadout.clear();p.constellation_allocations.clear();local.sim.combat.jobs.reset(p)
	var nodes=Content.SKILLS.runesword.filter(func(n):return n.effect=="active")
	for i in range(6):p.skill_ranks[nodes[i].id]=2;p.skill_loadout[Content.ACTIONS[i]]=nodes[i].id
	local.sim.recalculate(p);local.refresh();hud.refresh()
	p.skill_ranks[nodes[0].id]=3;changed(hud,p,"rank")
	p.stats.technique+=3;changed(hud,p,"technique")
	p.level+=1;changed(hud,p,"level")
	p.gear_stats.technique=int(p.gear_stats.get("technique",0))+7;changed(hud,p,"gear stats")
	p.inventory.append(preload("res://scripts/equipment_catalog.gd").make("sword",0,1,"cache-probe","guard",p.class_id));changed(hud,p,"inventory change")
	p.inventory[0].upgrade=2;changed(hud,p,"equipment upgrade")
	p.inventory.clear();changed(hud,p,"inventory removal")
	p.skill_loadout.skill_q=nodes[1].id;changed(hud,p,"loadout")
	var star=Rules.constellation_nodes(p.class_id)[0];p.constellation_allocations[star.id]=1;changed(hud,p,"specialization")
	var rebuilds=hud.metadata_rebuilds
	for state in [{"last_time":1.2,"last_skill":nodes[2].id},{"move_time":2.1},{"support_time":.8}]:
		p.constellation_state=state;p.job_state.runes=4;p.job_state.momentum=80.;local.refresh();hud.refresh();reference_cooldowns(hud,p,"temporary state")
	check(hud.metadata_rebuilds==rebuilds,"temporary resource state never rebuilds static cooldown geometry")
	for button in hud.circles.values()+[hud.bag_button,hud.growth_button,hud.codex_button]:
		for code in [KEY_SHIFT,KEY_SPACE,KEY_PAGEDOWN,KEY_BACKSPACE,KEY_CAPSLOCK]:
			button.hotkey=Keys.key_name(code);check(Rect2(Vector2.ZERO,button.size).encloses(button.hotkey_layout().rect),"long hotkey fits "+button.hotkey)
	hud.refresh_key_labels();p.charge_time=-1;p.class_id="mage";p.avatar="auto";p.costume="none";local.sim.combat.jobs.reset(p);local.refresh();hud.refresh()
	# Full authored width/top is preserved across all allowed portraits, including hats.
	for job in ["warrior","mage","ranger","rogue","fighter"]:
		p.class_id=job
		for costume in Content.costume_options(job):
			p.costume=costume;p.avatar="auto";local.refresh();hud.refresh()
			var source=Gat.frame({"class_id":p.class_id,"avatar":p.avatar,"costume":p.costume},0.).texture
			var visible_bounds=hud.visible_portrait_bounds(source)
			var expected_crop=Rect2(visible_bounds.position,Vector2(visible_bounds.size.x,ceilf(visible_bounds.size.y*.62)))
			check(hud.portrait_source_rect==expected_crop,"cached portrait matches selected atlas region "+job+" "+costume)
			check(Rect2(36,37,72,72).encloses(hud.portrait_rect()),"portrait stays inside medallion "+job+" "+costume)
			check(hud.portrait_source_rect.position.x>=0 and hud.portrait_source_rect.end.x<=hud.portrait_frame_size.x,"portrait source full width valid "+costume)
			check(hud.portrait_source_rect.position.y>=0 and hud.portrait_source_rect.end.y<=hud.portrait_frame_size.y,"portrait source top valid "+costume)
			if costume.contains("purple") or costume.contains("witch"):await capture("portrait-"+costume)
	p.class_id="mage";p.avatar="auto";p.costume="none";local.refresh();hud.refresh();await capture("hud")
	var map=game.map_overlay;map.queue_redraw();await frame();await frame();var static_draws=map.static_map.draws;var builds=map.static_builds
	for i in range(8):p.pos+=Vector2(.01,0);local.refresh();map.queue_redraw();await frame()
	check(map.static_map.draws==static_draws and map.static_builds==builds,"moving marker reuses retained terrain commands")
	check(map.static_map.floor_points.size()>0 and map.static_map.fixed_markers.size()>1,"retained town terrain and facilities present")
	game.toggle_bag();map.queue_redraw();await frame();check(not map.static_map.visible,"static minimap hidden with modal")
	check(hud.chrome_hidden and not hud.chrome.visible and game.bag.is_visible_in_tree() and not hud.circles.potion.is_visible_in_tree(),"full panel hides HUD chrome but remains interactive")
	game.toggle_bag();map.queue_redraw();await frame();check(map.static_map.visible,"static minimap restores after modal")
	check(not hud.chrome_hidden and hud.circles.potion.is_visible_in_tree(),"HUD restores after full panel closes")
	local.travel("forest");map.queue_redraw();await frame();await frame();check(map.static_builds==builds+1,"new dungeon invalidates terrain once")
	game.toggle_skills();var tree=game.skill_tree;await frame();check(hud.chrome_hidden and not hud.circles.interact.is_visible_in_tree(),"tree bottom does not expose clipped HUD captions");tree.search.grab_focus();var refreshes=tree.content_refreshes;var applications=tree.search_applications
	for letter in "echo":key(letter.to_upper().unicode_at(0),letter.unicode_at(0))
	check(tree.search.text=="echo","actual text events reach search")
	check(tree.content_refreshes==refreshes,"typing burst does not refresh immediately")
	await create_timer(.25).timeout;await frame()
	check(tree.search_applications==applications+1 and tree.content_refreshes==refreshes+1,"one debounced search performs one rebuild")
	key(KEY_A,97);key(KEY_ENTER);await frame();var submitted=tree.content_refreshes;await create_timer(.25).timeout
	check(tree.content_refreshes==submitted,"Enter consumes pending timer without duplicate refresh")
	tree.search.text="";tree.apply_search();popup_checks(tree.filter_picker,"tree type");popup_checks(tree.branch_picker,"tree branch");popup_checks(tree.tag_picker,"tree synergy");popup_checks(tree.class_picker,"class")
	for button in tree.bind_buttons:
		button.text="SHIFT 사용 중";tree.fit_bind_label(button)
		check(button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x<=button.size.x-20,"actual bold font fits long binding label")
	tree.refresh(true)
	tree.filter_picker.show_popup();await capture("tree-filter");tree.filter_picker.get_popup().hide()
	tree.tag_picker.show_popup();await capture("tree-tags");tree.tag_picker.get_popup().hide();game.toggle_skills();game.toggle_bag()
	popup_checks(game.bag.avatar_picker,"avatar");popup_checks(game.bag.costume_picker,"costume");game.bag.costume_picker.show_popup();await capture("costume-popup");game.bag.costume_picker.get_popup().hide();game.toggle_bag()
	check(await game.audio_director.shutdown(),"audio drained")
	print("PERFORMANCE_UI_V05 checks=%d failures=%d"%[checks,failures.size()]);print(JSON.stringify({"suite":"performance_ui_v05","checks":checks,"failures":failures,"metadata_rebuilds":hud.metadata_rebuilds,"profile_evaluations":hud.profile_evaluations,"minimap_static_builds":map.static_builds}));game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
