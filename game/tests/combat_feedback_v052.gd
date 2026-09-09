extends SceneTree
const Feedback=preload("res://scripts/combat_feedback.gd")
const Content=preload("res://scripts/content.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
var checks=0
var failures=[]
var captures=[]
var surface:SubViewport
var game
var feedback
var session
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func reset_player(class_id:String)->Dictionary:
	var p=session.sim.players[1];p.class_id=class_id;p.level=100;p.pos=Vector2(24,24);p.aim=Vector2.RIGHT;p.dir=Vector2.ZERO
	p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={};session.sim.combat.initialize(p);session.sim.recalculate(p)
	p.merge({"skill_cooldowns":{},"dodge_cd":0.,"dodge_time":0.,"charge_time":-1.,"invulnerable":0.,"barrier_time":0.,"haste_time":0.,"enemy_slow_time":0.,"combat_time":0.,"motion_time":0.,"swing":0.,"motion":"idle"},true)
	p.stamina=10000.;p.max_stamina=10000.;p.hp=p.max_hp;p.attack_cd=0.;p.job_state.runes=10
	session.sim.enemies.clear();session.sim.events.clear();session.sim.combat.projectiles.clear();session.sim.combat.skills.zones.clear();game.effects.clear()
	var enemy=session.sim.spawn_enemy("warden",p.pos+Vector2(3,0),1,true);enemy.hp=1000000;enemy.max_hp=1000000
	if class_id=="thief":session.sim.combat.jobs.mark(p,enemy)
	session.paused=false;session.refresh();feedback.clear();return p
func active(class_id:String,kind:String)->Dictionary:
	for node in Content.SKILLS[class_id]:
		if node.effect=="active" and Feedback.mode(node)==kind:return node
	check(false,"required mobility "+class_id+":"+kind);return {}
func equip_skill(p:Dictionary,node:Dictionary,slot:String="skill_q"):
	p.skill_ranks[node.id]=1;p.skill_loadout[slot]=node.id
func capture(name:String):
	# These fixtures jump the camera between poses; discard the old rendered
	# interpolation point so the captured actor uses the verified world anchor.
	game.smooth_positions.clear();game.queue_redraw();feedback.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=surface.get_texture().get_image();check(image.get_size()==Vector2i(1920,1080),"actual FullHD "+name)
	var path="res://../artifacts/combat-feedback-v052-"+name+".png";check(image.save_png(ProjectSettings.globalize_path(path))==OK,"capture "+name);captures.append(path)
func all_mobility():
	var covered={};var cast_count=0
	for class_id in Content.CLASSES:
		for node in Content.SKILLS[class_id]:
			if node.effect!="active" or not Feedback.mobility(node):continue
			covered[Feedback.mode(node)]=true;cast_count+=1
			var p=reset_player(class_id);equip_skill(p,node)
			check(session.act("skill_q"),"accepted real mobility "+node.id)
			check(feedback.recent.size()==1 and feedback.recent[0].id==node.id,"successful movement tracks exact skill "+node.id)
			if feedback.recent.is_empty():continue
			check(is_equal_approx(feedback.recent[0].remaining,float(p.skill_cooldowns[node.id])),"authoritative cooldown including return anchor "+node.id)
			var before=feedback.recent.duplicate(true)
			check(not session.act("skill_q") and feedback.recent==before,"failed repeat never restarts cooldown display "+node.id)
	for kind in Feedback.MOVEMENT:check(covered.has(kind),"all actual movement modes covered "+kind)
	check(cast_count>=30,"all base and advanced mobility nodes exercised")
	# A boss-anchored pull moves the player; a normal pull only moves the enemy.
	for kind in ["chain_pull","chain_group"]:
		var p=reset_player("reaper");var node=active("reaper",kind);equip_skill(p,node)
		var before=p.pos;check(session.act("skill_q") and p.pos.distance_to(before)>.05,"chain boss dash executes "+kind)
		check(feedback.recent.size()==1 and feedback.recent[0].id==node.id,"conditional boss dash appears "+kind)
		p=reset_player("reaper");equip_skill(p,node);session.sim.enemies[1].boss=false
		check(session.act("skill_q") and feedback.recent.is_empty(),"ordinary enemy pull is not movement "+kind)
func dodge_and_expiry():
	for class_id in Content.CLASSES:
		var p=reset_player(class_id);check(session.act("dodge"),"real dodge accepted "+class_id)
		var source=p.job_state.dash_timer if Content.job(p) else p.dodge_cd
		check(feedback.recent.size()==1 and is_equal_approx(feedback.recent[0].remaining,source),"actual class dodge timer "+class_id)
	var p=reset_player("warrior");p.stamina=0
	check(not session.act("dodge") and feedback.recent.is_empty(),"failed stamina action produces no feedback")
	p.stamina=100.;check(session.act("dodge"),"base dodge starts")
	session.sim.combat.tick_player(p,.81);feedback.refresh(0.)
	check(feedback.recent.size()==1 and feedback.slots[0].ready.visible and feedback.slots[0].number.text=="","actual cooldown ready uses brief check mark")
	feedback.refresh(.49);check(feedback.recent.size()==1,"ready feedback retained briefly")
	feedback.refresh(.02);check(feedback.recent.is_empty(),"ready feedback disappears after half second")
	p=reset_player("infighter");session.act("dodge");feedback.refresh()
	check(p.job_state.dash_charges==1 and feedback.slots[0].charges==1 and feedback.slots[0].maximum==2 and feedback.recent[0].remaining>0,"remaining infighter charge and refill shown together")
	session.act("dodge");feedback.refresh()
	check(p.job_state.dash_charges==0 and feedback.slots[0].charges==0,"second dodge consumes second displayed pip")
	session.sim.combat.tick_player(p,2.51);feedback.refresh()
	check(feedback.slots[0].charges==1 and feedback.recent[0].remaining>0,"first restored charge does not hide second refill")
	session.sim.combat.tick_player(p,2.51);feedback.refresh()
	check(feedback.slots[0].charges==2 and feedback.slots[0].ready.visible,"full charge restore shows actual readiness")
func limit_and_live_state():
	var p=reset_player("infighter");var nodes=Content.SKILLS.infighter
	var moving=nodes.filter(func(node):return node.effect=="active" and Feedback.mobility(node))
	var used=[]
	for index in range(4):
		var node=moving[index];equip_skill(p,node);p.job_state.lock=0;p.job_state.casting={};p.dodge_time=0
		check(session.act("skill_q"),"recent limit fixture cast "+node.id);used.append(node.id)
	check(feedback.recent.size()==3 and feedback.recent.map(func(record):return record.id)==used.slice(1),"only latest three mobility skills visible")
	var latest=feedback.recent.back().id;p.skill_cooldowns[latest]=1.23;feedback.refresh()
	check(feedback.slots[2].number.text=="1.3","countdown reads reduced live cooldown rather than estimated duration")
	p.job_state.lock=0;p.job_state.casting={};p.skill_cooldowns[latest]=0;session.act("skill_q")
	check(feedback.recent.size()==3 and feedback.recent.back().id==latest,"reuse refreshes existing icon without duplication")
	p=reset_player("warrior");var node=active("warrior","wave");equip_skill(p,node)
	check(session.act("skill_q") and feedback.recent.is_empty(),"ordinary attacks never add mobility icon")
	p.attack_cd=0;session.act("attack");check(feedback.recent.is_empty(),"basic attack has no permanent HUD icon")
func charge_geometry():
	var p=reset_player("warrior");check(session.act("heavy_begin"),"actual heavy charge begins")
	session.sim.enemies.clear()
	session.sim.combat.tick_player(p,.45);feedback.refresh()
	check(feedback.charge_visible and is_equal_approx(feedback.charge_ratio,.5) and feedback.charge_rect.size==Vector2(12,80),"orange vertical gauge uses exact .9s charge")
	for camera in [Transform2D.IDENTITY,Transform2D(Vector2(.72,0),Vector2(0,.72),Vector2(246,172))]:
		surface.canvas_transform=camera;game.camera_pos=Dungeon.iso(p.pos)+Vector2(112,-28);feedback.refresh()
		var expected=camera*game.world_point(p.pos)+Vector2(52,-98)
		var actual=feedback.get_global_transform_with_canvas()*feedback.charge_rect.position
		check(actual.is_equal_approx(expected),"charge follows transformed world position with CanvasLayer offset")
		session.sim.combat.tick_player(p,.45);feedback.refresh();check(feedback.charge_ratio==1.,"full charge clamps at 100 percent")
		session.refresh();await capture("charge-zoom" if camera!=Transform2D.IDENTITY else "charge")
	check(session.act("heavy"),"real heavy release accepted");feedback.refresh();check(not feedback.charge_visible,"release removes charge meter immediately")
	p.attack_cd=0;session.act("heavy_begin");session.act("cancel_charge");feedback.refresh();check(not feedback.charge_visible,"cancellation also removes meter")
	p.attack_cd=0;session.act("heavy_begin");session.act("dodge");feedback.refresh();check(not feedback.charge_visible and feedback.recent.size()==1,"dodge cancels charge and starts temporary cooldown")
func modal_cases():
	var p=reset_player("infighter");session.act("dodge");p.dodge_time=0;p.attack_cd=0;session.act("heavy_begin");session.sim.combat.tick_player(p,.45);session.refresh();feedback.refresh()
	session.sim.enemies.clear()
	for property in ["menu","bag","skill_tree","town_panel","codex","help_panel","settings_panel","character_sheet","npc_dialogue"]:
		var panel=game.get(property);panel.show();feedback.refresh();check(not feedback.visible and not feedback.charge_visible,"no feedback through "+property);panel.hide()
	session.paused=true;feedback.refresh();check(not feedback.visible,"pause hides both feedback types")
	session.paused=false;feedback.refresh();check(feedback.visible and feedback.charge_visible,"closing modal restores active charge")
	game.camera_pos=Dungeon.iso(p.pos);surface.canvas_transform=Transform2D.IDENTITY;session.refresh();feedback.refresh();await capture("infighter")
	check(not game.hud.circles.has("dodge") and not game.hud.circles.has("attack") and not game.hud.circles.has("heavy"),"no permanent basic action buttons restored")
	check(feedback.mouse_filter==Control.MOUSE_FILTER_IGNORE and feedback.slots.all(func(slot):return slot.holder.mouse_filter==Control.MOUSE_FILTER_IGNORE),"feedback never intercepts combat clicks")
	for slot in feedback.slots:check(slot.number.size.y>=slot.number.get_theme_font("font").get_height(slot.number.get_theme_font_size("font_size")),"countdown font has full glyph height")
	session.entered.emit();check(feedback.recent.is_empty(),"map entry clears stale previous-map movement")
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.size_2d_override=Vector2i(1600,900);surface.size_2d_override_stretch=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_embed_subwindows=true;root.add_child(surface)
	game=load("res://main.tscn").instantiate();game.options.mute=true;surface.add_child(game);await process_frame
	session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/combat-feedback-v052/"+str(Time.get_ticks_usec()));game.join_game()
	session.set_physics_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.set_process(false)
	feedback=game.get("combat_feedback");check(feedback!=null,"production main installs combat feedback")
	if feedback==null:game.stop_audio();quit(1);return
	feedback.set_process(false)
	for x in range(16,36):
		for y in range(16,36):session.sim.map.floor_cells[Vector2i(x,y)]=true
	session.sim.map.facility_cells.clear()
	all_mobility();dodge_and_expiry();limit_and_live_state();await charge_geometry();await modal_cases()
	session.disconnect_game();feedback.refresh();check(not feedback.visible and feedback.recent.is_empty(),"disconnect clears all combat feedback")
	var report=FileAccess.open("res://../artifacts/combat-feedback-v052.json",FileAccess.WRITE);report.store_string(JSON.stringify({"suite":"combat_feedback_v052","checks":checks,"failures":failures,"captures":captures},"\t"));report.close()
	game.stop_audio();game.queue_free();await process_frame;await process_frame;print("COMBAT_FEEDBACK_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
