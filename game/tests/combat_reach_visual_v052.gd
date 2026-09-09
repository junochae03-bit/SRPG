extends SceneTree
const Content=preload("res://scripts/content.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Active=preload("res://scripts/active_skills.gd")
var game
var checks=0
var failures=[]
var captures=[]
var logger:RenderErrors
class RenderErrors extends Logger:
	var errors:Array=[]
	var mutex=Mutex.new()
	func _log_error(function:String,file:String,line:int,code:String,rationale:String,_editor_notify:bool,_error_type:int,_backtraces:Array[ScriptBacktrace]):
		mutex.lock();errors.append("%s:%d %s %s %s"%[file,line,function,code,rationale]);mutex.unlock()
	func snapshot()->Array:
		mutex.lock();var result=errors.duplicate();mutex.unlock();return result
func _initialize():
	logger=RenderErrors.new();OS.add_logger(logger);run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("COMBAT_REACH_VISUAL_FAIL ",label)
func frame():
	game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
func fixture(job:String,kind:String="shade",offset:Vector2=Vector2(4,0))->Dictionary:
	var sim=game.session.sim
	sim.enemies.clear();sim.players.clear();sim.drops.clear();sim.events.clear();sim.combat.projectiles.clear();sim.combat.skills.zones.clear();sim.combat.constellation.pending.clear()
	game.effects.clear();game.smooth_positions.clear();game.monster_aim_frames.clear();game.hover_enemy_id=0
	var p=sim.add_player(1,"전투 검사",{"schema_version":7,"class_id":job,"level":100,"tutorial_done":true,"skill_ranks":{},"skill_loadout":{},"constellation_allocations":{}})
	p.pos=Vector2(24,24);p.stamina=10000.;p.max_stamina=10000.
	var e=sim.spawn_enemy(kind,p.pos+offset,1,kind=="warden");e.hp=1000000;e.max_hp=e.hp
	if e.has("stagger"):e.stagger.max_value=1000000.
	game.session.paused=false;game.session.refresh();game.update_battle_camera(p,0.,true)
	game.forest.update_camera(0.);game.toast.hide();game.visual_time=.25
	var focus=root.gui_get_focus_owner()
	if focus!=null:focus.release_focus()
	return {"sim":sim,"p":p,"e":e}
func point_for(id:int)->Vector2:
	var data:Dictionary=game.monster_aim_frames[id]
	var rect:Rect2=data.rect
	return data.transform*(rect.position+rect.size*Vector2(.5,.46))
func pointer(canvas:Vector2):
	# Inject the same logical viewport event that main._input receives from the
	# engine. This stays inside this window and never moves the OS cursor.
	var event=InputEventMouseMotion.new();event.position=root.canvas_transform*canvas;event.global_position=event.position
	root.push_input(event,true)
	check(game.aim_mouse_position().distance_to(canvas)<.25,"viewport mouse maps through actual camera transform expected=%s actual=%s viewport=%s"%[canvas,game.aim_mouse_position(),event.position])
func select_body(f:Dictionary):
	check(game.monster_aim_frames.has(f.e.id),"real draw_actor registered body "+f.e.kind)
	if not game.monster_aim_frames.has(f.e.id):return
	pointer(point_for(f.e.id));game._physics_process(.06)
	check(game.hover_enemy_id==f.e.id,"actual physics selects rendered body "+f.e.kind)
	check(f.p.aim.is_equal_approx(f.p.pos.direction_to(f.e.pos)),"actual player input points at selected foot "+f.e.kind)
func left_button(pressed:bool,canvas:Vector2):
	var event=InputEventMouseButton.new();event.position=root.canvas_transform*canvas;event.global_position=event.position
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	# Global button polling and viewport dispatch are separate engine APIs.
	Input.parse_input_event(event);Input.flush_buffered_events()
	root.push_input(event,true)
func click_attack(f:Dictionary):
	var at=point_for(f.e.id);left_button(true,at)
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"real input singleton holds left attack")
	check(root.gui_get_hovered_control()==null,"body pointer is in playable world")
	game._physics_process(.06);left_button(false,at)
	check(f.p.attack_cd>0,"main mouse polling dispatches actual basic attack")
	for step in range(25):f.sim.combat.tick_projectiles(.04)
	game.session.flush_events();game.session.refresh()
func capture(name:String):
	await frame();await frame()
	var image=root.get_texture().get_image();var path=ProjectSettings.globalize_path("res://../artifacts/combat-reach-v052-"+name+".png")
	check(image.get_size()==Vector2i(1920,1080),"Full HD framebuffer "+name)
	check(image.save_png(path)==OK,"capture "+name);captures.append(path)
func visual_aim():
	for kind in ["shade","orc_champion","warden"]:
		var f=fixture("ranger",kind,Vector2(4,0));await frame();select_body(f)
		check(f.p.pos.distance_to(f.e.pos)>Geometry.radius(f.e),"body aim test starts outside receiving volume")
		var old_hp=f.e.hp;click_attack(f)
		check(f.e.hp<old_hp,"body-selected projectile lands "+kind)
		await capture("body-"+kind)
		# Pan/zoom a real main canvas and register the transformed sprite again.
		game.camera_pos+=Vector2(63,-24);game.world_zoom=.68
		var anchor=game.screen_center();root.canvas_transform=Transform2D(Vector2(.68,0),Vector2(0,.68),anchor*(1.-.68))
		game.smooth_positions.clear();await frame();select_body(f)
		check(is_equal_approx(root.canvas_transform.x.length(),.68),"zoom fixture applies actual viewport canvas transform")
	# Overlapping sprite interiors resolve by actual painter order, not an
	# invented fixed-height rectangle or the nearest ground-center distance.
	var f=fixture("warrior","shade",Vector2(2.4,0))
	var front=f.sim.spawn_enemy("shade",f.e.pos+Vector2(.12,.12),1);front.hp=1000000;front.max_hp=front.hp
	game.session.refresh();game.smooth_positions.clear();await frame()
	var a:Dictionary=game.monster_aim_frames[f.e.id];var b:Dictionary=game.monster_aim_frames[front.id]
	check(int(b.depth)>int(a.depth),"front monster has later real rendering depth")
	pointer(point_for(front.id));game._physics_process(.06)
	check(game.hover_enemy_id==front.id and f.p.aim.is_equal_approx(f.p.pos.direction_to(front.pos)),"actual pointer selects frontmost overlapping body")
	await capture("front-selection")
	# Body targeting helps aim, but never bypasses weapon reach.
	for spec in [["warrior",Vector2(4,0)],["ranger",Vector2(0,10.5)]]:
		f=fixture(spec[0],"shade",spec[1]);await frame();select_body(f)
		var hp=f.e.hp;click_attack(f)
		check(f.e.hp==hp,"visible out-of-range body remains unharmed "+spec[0])
	f=fixture("warrior","shade",Vector2(2.6,0));await frame();select_body(f)
	var hp=f.e.hp;click_attack(f);check(f.e.hp<hp,"actual torso-click sword swing includes enlarged body edge")
func visual_areas():
	for spec in [["mage","frost_nova"],["ranger","arrow_rain"],["warrior","whirlwind"]]:
		var f=fixture(spec[0]);var node:Dictionary={}
		for candidate in Content.SKILLS[spec[0]]:
			if candidate.id==spec[1]:node=candidate
		check(not node.is_empty(),"area skill definition "+spec[1])
		if node.is_empty():continue
		f.p.skill_ranks[node.id]=1;f.p.skill_loadout.skill_q=node.id
		var s=Scaling.profile(node,1,Active.bonuses(f.p));var center=f.p.pos+Vector2(3.5,0) if spec[1]=="arrow_rain" else f.p.pos
		f.e.pos=center+Vector2(s.radius+.6,0)
		for off in [Vector2(-2,1),Vector2(0,-2),Vector2(1.5,1.3)]:
			var enemy=f.sim.spawn_enemy("shade",center+off,1);enemy.hp=1000000;enemy.max_hp=enemy.hp
		game.session.refresh();game.smooth_positions.clear();await frame();select_body(f)
		check(game.session.act("skill_q"),"real local cast "+node.id)
		for step in range(9):f.sim.combat.skills.tick(.04)
		game.session.flush_events();game.session.refresh()
		check(f.e.hp<f.e.max_hp,"actual area hits beyond former sprite-center radius "+node.id)
		var matched=game.effects.filter(func(e):return e.get("skill_id","")==node.id and e.get("ground_shape","")=="circle")
		check(not matched.is_empty() and is_equal_approx(float(matched[0].radius),float(s.radius)),"render event retains actual broad area "+node.id)
		for effect in game.effects:effect.life=float(effect.max_life)*.63
		await capture(spec[1])
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	check(DisplayServer.get_name()!="headless","visual reach check requires actual renderer")
	if not failures.is_empty():finish();return
	Content.initialize_jobs();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts"))
	game=load("res://main.tscn").instantiate();game.options={"mute":true,"save-dir":ProjectSettings.globalize_path("res://../runtime/combat-reach-visual-v052/"+str(Time.get_ticks_usec()))}
	root.add_child(game);game.process_mode=Node.PROCESS_MODE_ALWAYS;game.set_process(false);game.set_physics_process(false);game.set_process_input(true);game.set_process_unhandled_input(false);game.set_process_unhandled_key_input(false)
	# Keep actual main._input live while simulations, animations and audio tick
	# only at explicit deterministic points in this visual regression.
	for child in game.get_children():child.process_mode=Node.PROCESS_MODE_DISABLED
	game.session.set_physics_process(false)
	await process_frame;game.join_game();game.session.sim.players[1].tutorial_done=true;game.session.change_map("forest",1)
	# A local isolated open patch keeps this check about render/input geometry;
	# procedural route and obstacle correctness are tested in dungeon_variety.
	for x in range(15,40):
		for y in range(15,40):game.session.sim.map.floor_cells[Vector2i(x,y)]=true
	game.forest.rebuild(game.session.sim.map)
	await visual_aim();await visual_areas()
	left_button(false,Vector2.ZERO);await game.audio_director.shutdown();game.session.disconnect_game();game.queue_free();await process_frame;await process_frame
	finish()
func finish():
	var errors=logger.snapshot();check(errors.is_empty(),"actual main rendering has no engine or script errors")
	for error in errors:print("COMBAT_REACH_VISUAL_RENDER_ERROR ",error)
	OS.remove_logger(logger)
	print("COMBAT_REACH_VISUAL_V052 checks=",checks," failures=",failures.size()," captures=",captures.size())
	for path in captures:print("COMBAT_REACH_VISUAL_CAPTURE ",path)
	quit(0 if failures.is_empty() else 1)
