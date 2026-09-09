extends SceneTree
const World=preload("res://scripts/world_catalog.gd")
const Training=preload("res://scripts/training_ground.gd")
const TrainingArt=preload("res://scripts/training_art.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
var checks=0
var failures:Array=[]
var captures:Array=[]
var walked=0
var game
var local
var p:Dictionary

func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func route(goal:Vector2)->Array:
	var start=Vector2i(roundi(p.pos.x),roundi(p.pos.y));var end=Vector2i(roundi(goal.x),roundi(goal.y))
	var queue=[start];var previous={start:start};var cursor=0
	while cursor<queue.size() and not previous.has(end):
		var cell=queue[cursor];cursor+=1
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next=cell+offset
			if local.sim.map.walkable(Vector2(next)) and not previous.has(next):previous[next]=cell;queue.append(next)
	if not previous.has(end):return []
	var result=[end]
	while result.back()!=start:result.append(previous[result.back()])
	result.reverse();result.append(goal);return result

func walk_to(goal:Vector2)->bool:
	var points=route(goal)
	if points.is_empty():return false
	for point in points:
		var target=Vector2(point);var attempts=0
		while p.pos.distance_to(target)>.05 and attempts<80:
			var difference=target-p.pos
			local.sim.set_input(1,difference.normalized(),Vector2.RIGHT)
			local.sim.tick(minf(.03,difference.length()/local.sim.balance.player.speed))
			attempts+=1;walked+=1
		if p.pos.distance_to(target)>.05:return false
	local.sim.set_input(1,Vector2.ZERO,Vector2.RIGHT)
	return true

func capture(name:String):
	local.refresh();game.update_battle_camera(p,1.,true);game.smooth_positions.clear();game.forest.update_camera(1.);game.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1920,1080),"actual FullHD "+name)
	var path=ProjectSettings.globalize_path("res://../artifacts/town-renewal-v052-"+name+".png")
	check(image.save_png(path)==OK,"capture "+name);captures.append(path)
	check(game.forest.props.all(func(prop):return game.forest.clear_for_prop(prop.pos)),"no foliage on renewed routes "+name)
	return image

func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/town-renewal-v052/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();local=game.session
	local.sim.players[1].tutorial_done=true;check(local.travel("town"),"actual arrival at renewed town")
	local.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	p=local.sim.players[1];p.level=100;p.highest_floor=100;local.sim.recalculate(p)
	check(local.sim.map.layout_id=="town_plaza" and local.sim.map.walkable(p.pos),"renewed plaza retains valid arrival")
	check(World.FACILITIES.size()==8 and World.RESIDENTS.size()==7,"dedicated boutique and instructor")
	await capture("plaza")
	for key in ["smith","shop","alchemy","guild","inn","costume"]:
		var destination=World.FACILITIES[key].pos+Vector2(2.5,1.8)
		check(walk_to(destination),"actual input movement reaches "+key)
		check(World.nearest(p.pos)==key,"correct service proximity "+key)
		if key=="costume":
			await capture("boutique-exterior")
			check(local.act("interact") and game.npc_dialogue.visible and game.npc_dialogue.speaker.text==World.RESIDENTS.costume.name,"boutique E opens named tailor")
			game.npc_dialogue.service_button.pressed.emit()
			check(game.town_panel.facility=="costume" and game.town_panel.wardrobe_view!=null,"tailor opens existing wardrobe transaction UI")
			game.town_panel.close()
	var stand=Vector2(36,33)
	check(walk_to(stand) and Training.can_practice(local.sim,p),"broad input route enters practice green")
	check(not local.sim.map.in_town(p.pos) and local.sim.map.in_town(World.FACILITIES.portal.pos),"practice and portal safety do not overlap")
	var before_critical:Image=await capture("training-green")
	var targets=local.sim.enemies.values().filter(func(e):return e.get("training",false))
	check(targets.size()==1,"one actual giant practice target")
	if not targets.is_empty():
		var target=targets[0]
		check(target.pos==Training.POSITION and target.hp==Training.HEALTH,"target fixed home and practice HP")
		check(game.monster_aim_frames.has(target.id),"actual renderer registers target body")
		if game.monster_aim_frames.has(target.id):
			var frame=game.monster_aim_frames[target.id]
			check(is_equal_approx(frame.rect.size.y,300.) and is_equal_approx(frame.rect.end.y,0.),"300 logical pixel target with feet anchored at floor")
			check(frame.transform.origin.distance_to(game.world_point(target.pos))<1.,"drawn target anchor matches simulation feet")
		# Inject a documented display fixture through the real event consumer.
		# Damage/critical calculations themselves are covered by combat tests.
		game.preferences.values.damage_numbers=true
		game.on_event({"type":"damage","pos":target.pos,"amount":12345,"enemy":true,"owner":1,"critical":true})
		var critical:Image=await capture("training-critical")
		var changed_red=0
		for x in range(0,critical.get_width(),2):
			for y in range(0,critical.get_height(),2):
				var a=critical.get_pixel(x,y);var b=before_critical.get_pixel(x,y)
				if a.r>.86 and a.g<.42 and a.b<.42 and absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.18:changed_red+=1
		check(changed_red>80,"real critical event paints bold red glyphs over unchanged training scene")
		check(game.bold_font.resource_path.ends_with("dnf_bitbit_v2.ttf"),"critical glyphs use requested bold font")
		game.effects.clear()
	var art=TrainingArt.texture()
	check(art is AtlasTexture and art.atlas.resource_path==TrainingArt.SOURCE and art.region.has_area(),"registered transparent source used by actual target")
	check(local.act("interact") and game.npc_dialogue.facility=="training","E reaches training instructor from practice circle")
	game.npc_dialogue.service_button.pressed.emit()
	check(game.town_panel.facility=="training" and game.town_panel.counter.texture==TrainingArt.texture(),"training review uses same completed target art")
	game.town_panel.close()
	check(walk_to(World.FACILITIES.portal.pos+Vector2(1.6,1.2)),"walk from practice green to separate dungeon entrance")
	check(World.nearest(p.pos)=="portal" and local.sim.map.in_town(p.pos),"portal approach remains safe")
	await capture("portal-exterior")
	check(local.act("interact") and game.town_panel.facility=="portal","actual portal E opens floor picker")
	game.town_panel.close()
	check(await game.audio_director.shutdown(),"audio drained")
	local.connected=false;game.queue_free();game=null;await process_frame;await process_frame
	print("TOWN_RENEWAL_VISUAL_V052 checks=",checks," failures=",failures.size()," movement_steps=",walked," captures=",JSON.stringify(captures))
	quit(0 if failures.is_empty() else 1)
