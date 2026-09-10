extends RefCounted
## Opt-in normal-action QA driver. Main isolates its saves before initialization.
const Content=preload("res://scripts/content.gd")
var game_ref:WeakRef
var game:
	get:return game_ref.get_ref()
const Rules=preload("res://scripts/skill_build.gd")
const Stats=preload("res://scripts/progression.gd")
const World=preload("res://scripts/world_catalog.gd")
const Gear=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Quote=preload("res://scripts/service_quote.gd")
var started=Time.get_ticks_msec()
var out=""
var duration_s=1800.0
var next_action=0.0
var next_sample=0.0
var next_capture=0.0
var hold_until=0.0
var route=[]
var route_goal=Vector2.INF
var last_map=""
var events_file:FileAccess
var samples_file:FileAccess
var marks={}
var previous={}
var frames=[]
var frame_at=0
var previous_pos=Vector2.ZERO
var stopped_for=0.0
var last_progress=0.0
var town_phase=0
var finished=false
var total_actions=0
var successful_actions=0
var next_menu=120.0
var menu_index=0
var method_times={}
var frame_state={}
func timing(key:String,begin:int):
	if not method_times.has(key):method_times[key]=[]
	method_times[key].append((Time.get_ticks_usec()-begin)/1000.)
func seconds()->float:return (Time.get_ticks_msec()-started)/1000.0
func record(kind:String,extra:Dictionary={}):
	var value={"at_s":seconds(),"kind":kind};value.merge(extra)
	events_file.store_line(JSON.stringify(value))
func milestone(key:String):
	if marks.has(key):return
	marks[key]=seconds();record("milestone",{"name":key});capture_scene.call_deferred(key)
func capture_scene(key:String):
	record("capture_begin",{"name":key})
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(out.path_join(key+".png"))
	record("capture_end",{"name":key})
func setup(owner_game):
	game_ref=weakref(owner_game)
	for arg in OS.get_cmdline_user_args():
		var pair=arg.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1] if pair.size()>1 else "true"
	out=str(options["observation-output"]);duration_s=float(options.get("observation-seconds","1800"))
	DirAccess.make_dir_recursive_absolute(out)
	events_file=FileAccess.open(out.path_join("events.jsonl"),FileAccess.WRITE)
	samples_file=FileAccess.open(out.path_join("samples.jsonl"),FileAccess.WRITE)
	options["save-dir"]=out.path_join("saves");options.erase("duration");options.erase("play");options.erase("bot")
	Engine.max_fps=60;game.get_window().borderless=true;game.get_window().size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if options.get("observation-vsync","on")=="off" else DisplayServer.VSYNC_ENABLED)
	session.event_received.connect(func(event):
		if event.type in ["damage","monster_attack","notice","skill_fx"]:record("game_event",{"event":event}))
	game.set_process_input(false);game.set_process_unhandled_input(false);game.set_process_unhandled_key_input(false)
	record("configuration",{"class":options.get("observation-class","warrior"),"pid":OS.get_process_id(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"fps_limit":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"refresh_hz":DisplayServer.screen_get_refresh_rate(),"new_save":true,"controller":"normal actions; no stat/currency/position cheats"})
	milestone("title");hold_until=2.0
func perform(action:String,arg:String="")->bool:
	total_actions+=1
	var ok=session.act(action,arg)
	if ok:successful_actions+=1
	if ok and action not in ["attack","skill_q","skill_f","skill_v","skill_c","skill_z","skill_x"]:record("action",{"action":action,"argument":arg})
	return ok
func walk_to(goal:Vector2,p:Dictionary)->Vector2:
	if p.pos.distance_to(goal)<.6:return Vector2.ZERO
	if route.is_empty() or route_goal.distance_to(goal)>1.5 or not dungeon.line_clear(p.pos,route[0]) or p.pos.distance_to(route[0])>2.3:
		route=make_route(p.pos,goal);route_goal=goal
	while not route.is_empty() and p.pos.distance_to(route[0])<.35:route.pop_front()
	return p.pos.direction_to(route[0]) if not route.is_empty() else Vector2.ZERO
func close_panels():
	for panel in [bag,skill_tree,help_panel,settings_panel,town_panel,codex,npc_dialogue]:
		if panel.visible and panel.has_method("close"):panel.close()
	if bag.visible:toggle_bag()
	if skill_tree.visible:toggle_skills()
func physics(delta:float):
	var begin=Time.get_ticks_usec();drive(delta);timing("controller",begin)
func drive(delta:float):
	if finished or session==null:return
	if seconds()<hold_until:
		if session.connected:session.send_input(Vector2.ZERO,Vector2.RIGHT)
		return
	if not session.connected:
		if not character_sheet.visible:
			begin_adventure();milestone("creation");hold_until=seconds()+2.;return
		var cls=str(options.get("observation-class","warrior"))
		record("creation_phase",{"phase":"select_class_begin"});events_file.flush()
		character_sheet.select_class(cls);record("creation_phase",{"phase":"select_class_end"})
		character_sheet.sheet.stats=preload("res://scripts/character_creation.gd").suggested(cls)
		character_sheet.name_field.text="관찰 "+Content.CLASSES[cls].name;character_sheet.name_field.text_changed.emit(character_sheet.name_field.text)
		record("creation_phase",{"phase":"name_refresh_end"})
		character_sheet.refresh();record("creation_phase",{"phase":"submit_begin"});events_file.flush()
		character_sheet.create_button.pressed.emit();record("creation_phase",{"phase":"submit_end"})
		milestone("created");hold_until=seconds()+1.;return
	if seconds()<next_action:return
	next_action=seconds()+.12
	close_panels()
	if seconds()>=next_menu:
		next_menu=seconds()+120.;menu_index+=1
		match menu_index%4:
			0:game.toggle_bag()
			1:game.toggle_skills()
			2:game.toggle_codex()
			3:game.settings_panel.open()
		record("menu",{"index":menu_index,"view":["bag","skills","codex","settings"][menu_index%4]});hold_until=seconds()+4.;return
	var p=session.sim.players[session.local_id]
	var map_key=session.sim.map.zone+":"+str(session.sim.map.floor_number)
	if map_key!=last_map:
		last_map=map_key;route.clear();route_goal=Vector2.INF;town_phase=0
		record("map",{"map":map_key,"level":p.level,"gold":p.gold});milestone("map-"+map_key.replace(":","-"))
	if not previous.is_empty():
		if p.level!=previous.level:milestone("first-level");record("level",{"level":p.level,"xp":p.xp,"gold":p.gold})
		if p.inventory.size()>previous.inventory:milestone("first-equipment-drop");record("equipment_drop",{"count":p.inventory.size()})
		if p.kills>previous.kills:last_progress=seconds()
	previous={"level":p.level,"inventory":p.inventory.size(),"kills":p.kills}
	if Stats.available(p)>0:
		perform("stat","endurance" if Stats.available(p)%3==0 else "magic" if Content.base_class(p.class_id)=="mage" else "strength");milestone("first-stat")
	if Rules.available_points(p)>0:
		var choices=Rules.nodes_for(p.class_id).filter(func(n):return n.effect=="active" and Rules.rank(p,n)==0 and Rules.node_state(p,n.id).can_invest)
		if choices.is_empty():choices=Rules.nodes_for(p.class_id).filter(func(n):return Rules.node_state(p,n.id).can_invest)
		if not choices.is_empty() and perform("invest",choices[0].id):
			if not marks.has("first-skill"):toggle_skills();skill_tree.select_node(choices[0].id);milestone("first-skill");hold_until=seconds()+2.;return
	for item in p.inventory:
		if not Gear.reason(p,item).is_empty():continue
		var equipped=preload("res://scripts/inventory_model.gd").find_item(p,p.equipment.get(item.slot,""))
		if equipped.get("id","")==item.id:continue
		if int(item.bonus)>int(equipped.get("bonus",-1)):
			if not marks.has("first-comparison"):toggle_bag();bag.select_item(item.id);milestone("first-comparison");hold_until=seconds()+2.;return
			if perform("equip",item.id):milestone("first-equipment-change")
	if session.sim.map.zone=="town":
		var facility=["inn","smith","shop","portal"][mini(town_phase,3)]
		var target=World.resident_pos(facility) if World.RESIDENTS.has(facility) else World.FACILITIES[facility].pos
		if World.nearest(p.pos)!=facility:session.send_input(walk_to(target+Vector2(.5,1.),p),Vector2.RIGHT);return
		if town_phase==0:
			if not marks.has("first-inn-dialogue"):
				perform("interact");milestone("first-inn-dialogue");hold_until=seconds()+2.;return
			if not marks.has("first-inn-service"):
				game.town_panel.open("inn");milestone("first-inn-service");hold_until=seconds()+2.;return
			perform("facility",JSON.stringify({"facility":"inn","operation":"resupply_small"}));town_phase=1;return
		if town_phase==1:
			var weapon=Inventory.find_item(p,p.equipment.get("weapon",""))
			if not weapon.is_empty() and int(weapon.get("upgrade",0))<maxi(2,Gear.UNLOCK[int(weapon.rarity)]):
				# Recycle only clearly superseded unequipped gear; retain 85G for recovery.
				for old in p.inventory:
					if old.get("category","") not in ["weapon","armor","accessory"] or Inventory.is_equipped(p,old.id):continue
					var equipped=Inventory.find_item(p,p.equipment.get(old.slot,""))
					if not equipped.is_empty() and int(old.bonus)<int(equipped.bonus):
						if perform("facility",JSON.stringify({"facility":"smith","operation":"salvage","item":old.id})):milestone("first-salvage");return
				var q=Quote.quote(p,"smith","upgrade",{"item":weapon.id})
				if q.reason.is_empty() and int(p.gold)-int(q.cost)>=85:
					if not marks.has("first-smith-preview"):
						game.town_panel.open("smith");game.town_panel.choose("upgrade",{"item":weapon.id});milestone("first-smith-preview");hold_until=seconds()+2.;return
					if perform("facility",JSON.stringify({"facility":"smith","operation":"upgrade","item":weapon.id})):
						var updated=session.sim.players[session.local_id];var current=Inventory.find_item(updated,weapon.id)
						milestone("first-smith-upgrade");record("smith_upgrade",{"item":weapon.id,"upgrade":current.get("upgrade",0),"gold":updated.gold,"ore":updated.materials.ore})
						if int(current.rarity)>0 and int(current.get("upgrade",0))>=Gear.UNLOCK[int(current.rarity)]:milestone("first-option-unlock")
						return
			town_phase=2;return
		if town_phase==2:
			for index in range(Gear.SHOP_TYPES.size()):
				var q=Quote.quote(p,"shop","buy",{"index":index})
				if not q.item.is_empty() and p.equipment.get(q.item.slot,"")=="" and q.reason.is_empty() and int(p.gold)-int(q.cost)>=85:
					if perform("facility",JSON.stringify({"facility":"shop","operation":"buy","index":index})):milestone("first-shop-equipment");return
			town_phase=3;return
		var index=0
		for n in Content.SKILLS[p.class_id]:
			if n.effect=="active" and int(p.skill_ranks.get(n.id,0))>0 and index<Content.ACTIONS.size():perform("bind_skill",Content.ACTIONS[index]+":"+n.id);index+=1
		if session.enter_floor(mini(10,int(p.highest_floor))):milestone("first-dungeon")
		return
	if not p.tutorial_done and p.tutorial_kills>=5:
		if perform("return"):milestone("tutorial-complete")
		return
	var unbound=Content.SKILLS[p.class_id].any(func(n):return n.effect=="active" and int(p.skill_ranks.get(n.id,0))>0 and not p.skill_loadout.values().has(n.id))
	if p.tutorial_done and unbound and p.skill_loadout.size()<6:
		if perform("return"):record("return_to_bind")
		return
	if p.hp<p.max_hp*.45:perform("potion")
	if p.tutorial_done and p.hp<p.max_hp*.22 and p.potions==0:
		if perform("return"):record("retreat",{"gold":p.gold,"level":p.level})
		return
	if session.sim.map.floor_number>0 and p.cleared_floor>=session.sim.map.floor_number:
		if session.sim.map.floor_number>=10:
			milestone("first-boss-cleared");perform("return");return
		session.send_input(walk_to(dungeon.exit_position,p),Vector2.RIGHT)
		if p.pos.distance_to(dungeon.exit_position)<2.5:perform("interact")
		return
	var direction=Vector2.ZERO;var aim=Vector2.RIGHT
	var drops=session.state.drops.values().filter(func(d):return d.owner==p.id and p.pos.distance_to(d.pos)<3.)
	if not drops.is_empty():
		drops.sort_custom(func(a,b):return p.pos.distance_squared_to(a.pos)<p.pos.distance_squared_to(b.pos))
		if p.pos.distance_to(drops[0].pos)<1.7:perform("interact")
		else:session.send_input(walk_to(drops[0].pos,p),p.pos.direction_to(drops[0].pos));return
	var enemies=session.state.enemies.values().filter(func(e):return e.hp>0 and not e.get("training",false))
	enemies.sort_custom(func(a,b):return p.pos.distance_squared_to(a.pos)<p.pos.distance_squared_to(b.pos))
	if not enemies.is_empty():
		var e=enemies[0];aim=p.pos.direction_to(e.pos)
		var distance=p.pos.distance_to(e.pos);var ranged=Content.base_class(p.class_id) in ["ranger","mage"]
		if e.windup>0 and p.pos.distance_to(e.attack_pos)<2.5:
			direction=aim.rotated(PI*.5);session.send_input(direction,aim);perform("dodge")
		elif distance>(4. if ranged else 1.5) or not dungeon.line_clear(p.pos,e.pos):direction=walk_to(e.pos,p)
		elif ranged and distance<2.:direction=-aim
		session.send_input(direction,aim)
		if distance<6. and dungeon.line_clear(p.pos,e.pos):
			for action in Content.ACTIONS:
				if Content.action_rank(p,action)>0:perform(action)
			if p.charge_time>=.75:perform("heavy")
			elif int(seconds())%7==0 and distance<2.:perform("heavy_begin")
			else:perform("attack")
	else:
		direction=walk_to(dungeon.exit_position,p);session.send_input(direction,aim)
	if session.sim.map.floor_number>0 and p.pos.distance_to(dungeon.exit_position)<2.5:perform("interact")
	if p.pos.distance_to(previous_pos)<.03 and direction.length()>.1:stopped_for+=.12
	else:stopped_for=0.
	previous_pos=p.pos
	if stopped_for>5.:record("blocked_movement",{"map":map_key,"pos":[p.pos.x,p.pos.y]});route.clear();stopped_for=0.;session.send_input(aim.rotated(PI*.5),aim);perform("dodge")
func process(_delta:float):
	var now=Time.get_ticks_usec()
	if frame_at>0:frames.append((now-frame_at)/1000.)
	frame_at=now
	timing("collector_prefix",now)
	if finished:return
	var state_now={"view":"bag" if bag.visible else "skills" if skill_tree.visible else "codex" if codex.visible else "settings" if settings_panel.visible else "town-service" if town_panel.visible else "dialogue" if npc_dialogue.visible else "gameplay","focused":DisplayServer.window_is_focused()}
	if frame_state!=state_now:
		record("frame_state",state_now);frame_state=state_now
	if seconds()>=next_sample:
		next_sample=seconds()+10.
		var sample={"at_s":seconds(),"fps_limit":Engine.max_fps,"static_memory":OS.get_static_memory_usage(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"focused":DisplayServer.window_is_focused(),"frames_ms":frames.duplicate(),"route":route.map(func(v):return [v.x,v.y])};frames.clear()
		sample["view"]="bag" if bag.visible else "skills" if skill_tree.visible else "codex" if codex.visible else "settings" if settings_panel.visible else "town-service" if town_panel.visible else "gameplay"
		sample["method_ms"]=method_times.duplicate(true);method_times.clear();sample["engine_process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000.;sample["engine_physics_ms"]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.
		if session.connected:
			var p=session.sim.players[session.local_id];sample.merge({"level":p.level,"xp":p.xp,"gold":p.gold,"kills":p.kills,"hp":p.hp,"max_hp":p.max_hp,"potions":p.potions,"floor":session.sim.map.floor_number,"zone":session.sim.map.zone,"items":p.inventory.size(),"pos":[p.pos.x,p.pos.y]})
			sample["bosses"]=[]
			for enemy in session.state.enemies.values():
				if enemy.get("boss",false):
					var row={}
					for key in ["id","kind","name","hp","max_hp","phase","stagger","stagger_max","staggered","windup"]:
						if enemy.has(key):row[key]=enemy[key]
					sample.bosses.append(row)
		samples_file.store_line(JSON.stringify(sample));samples_file.flush();events_file.flush()
	if seconds()>=duration_s:game.finish_run()
func finish():
	if finished:return
	finished=true
	if not frames.is_empty():
		samples_file.store_line(JSON.stringify({"at_s":seconds(),"partial":true,"frames_ms":frames,"method_ms":method_times}));samples_file.flush();frames.clear()
	record("finish",{"elapsed_s":seconds(),"milestones":marks,"attempts":total_actions,"successful_actions":successful_actions})
	if session.connected:
		var file=FileAccess.open(out.path_join("final-player.json"),FileAccess.WRITE);file.store_string(JSON.stringify(session.sim.persistent(session.local_id)));file.close()
	await capture_scene("final")
	events_file.flush();samples_file.flush()

var options:
	get:return game.options

var session:
	get:return game.session

var dungeon:
	get:return game.dungeon

var bag:
	get:return game.bag

var skill_tree:
	get:return game.skill_tree

var help_panel:
	get:return game.help_panel

var settings_panel:
	get:return game.settings_panel

var town_panel:
	get:return game.town_panel

var codex:
	get:return game.codex

var npc_dialogue:
	get:return game.npc_dialogue

var character_sheet:
	get:return game.character_sheet

func begin_adventure():game.begin_adventure()

func toggle_bag():game.toggle_bag()

func toggle_skills():game.toggle_skills()

func make_route(start:Vector2,goal:Vector2)->Array:return game.make_route(start,goal)
