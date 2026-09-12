extends SceneTree
## Real creator/session/inventory/HUD consumers of the externally authored pack.
## Every save is isolated in runtime; the reader and raster sources are read-only.
const Costumes=preload("res://scripts/costume_art_v04.gd")
const Content=preload("res://scripts/content.gd")
const Creation=preload("res://scripts/character_creation.gd")
const Local=preload("res://scripts/local_session.gd")
const Gat=preload("res://scripts/gat_art.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Progression=preload("res://scripts/progression.gd")
const Wardrobe=preload("res://scripts/wardrobe.gd")
const World=preload("res://scripts/world_catalog.gd")
var checks=0
var failures=[]
var captures=[]
var logger:RuntimeErrors

class RuntimeErrors extends Logger:
	var errors=[]
	var mutex=Mutex.new()
	func _log_error(function:String,file:String,line:int,code:String,rationale:String,_notify:bool,_type:int,_traces:Array[ScriptBacktrace])->void:
		mutex.lock();errors.append("%s:%d %s: %s %s"%[file,line,function,code,rationale]);mutex.unlock()
	func snapshot()->Array:
		mutex.lock();var result=errors.duplicate();mutex.unlock();return result

func _initialize():
	logger=RuntimeErrors.new();OS.add_logger(logger);run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("COSTUME_SESSION_FAIL ",label)
func click(control:Control):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func key(code:int):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func logical_viewport()->Rect2:
	return Rect2(Vector2.ZERO,Vector2(ProjectSettings.get_setting("display/window/size/viewport_width",1440),ProjectSettings.get_setting("display/window/size/viewport_height",900)))
func canvas_rect(control:Control)->Rect2:
	var transform=control.get_global_transform_with_canvas()
	return Rect2(transform*Vector2.ZERO,control.size*transform.get_scale())
func draw_frame():
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name:String):
	await draw_frame()
	var path=ProjectSettings.globalize_path("res://../artifacts/v04-costume-"+name+".png");DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image=root.get_texture().get_image();var expected=Vector2i(ProjectSettings.get_setting("display/window/size/window_width_override",1440),ProjectSettings.get_setting("display/window/size/window_height_override",900));check(image.get_size()==expected,"configured full-resolution capture "+name)
	check(image.save_png(path)==OK,"capture "+name);captures.append(path);print("COSTUME_SESSION_CAPTURE ",path)
func identity_except_costume(p:Dictionary,sim)->Dictionary:
	var result={}
	for field in ["class_id","avatar","stats","creation_points","inventory","equipment","equipped","bag_positions","materials","gold","level","xp","skill_ranks","constellation_allocations","skill_loadout","training_given","owned_appearances"]:result[field]=p.get(field)
	result.damage=sim.damage_for(p);result.magic_damage=sim.damage_for(p,"magic");result.defense=p.defense;result.max_hp=p.max_hp
	result.cooldown=Progression.cooldown_factor(p);result.attack_speed=Progression.attack_speed(p);result.move_speed=Progression.move_speed(p)
	return result.duplicate(true)
func starter_checks(p:Dictionary,sim,label:String):
	check(p.inventory.size()==4 and p.training_given,label+" automatically receives exactly four starter pieces")
	check(p.equipment.values().filter(func(id):return id!="").size()==4,label+" four pieces are equipped")
	for slot in ["weapon","head","chest","feet"]:check(not Inventory.find_item(p,p.equipment.get(slot,"")).is_empty(),label+" equipped "+slot)
	check(sim.combat.weapon_type(p)==Content.CLASSES[p.class_id].weapon and Inventory.find_item(p,p.equipped).job_lock==p.class_id,label+" chosen-class weapon")
	check(Inventory.bag_items(p).size()==1,label+" equipped gear consumes no bag cells; potion stack remains")
	check(not sim.action(1,"claim_starters"),label+" cannot duplicate automatic starter kit")
func label_fits(label:Label,context:String):
	var font=label.get_theme_font("font");var font_size=label.get_theme_font_size("font_size")
	check(label.get_line_height()<=label.size.y,context+" line height")
	check(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=label.size.x+1,context+" text width")

func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	Content.initialize_jobs();var ids=Costumes.ids();check(ids.size()==33,"33 registered costume source sheets")
	var player_ids=[];var npc_ids=[];var allowed_class={}
	for id in ids:
		var classes=Creation.CLASSES.filter(func(cls):return id in Content.costume_options(cls))
		if classes.is_empty():npc_ids.append(id)
		else:player_ids.append(id);allowed_class[id]=classes[0]
	check(player_ids.size()==30 and npc_ids.size()==3,"thirty playable costumes and three firearm NPC appearances")
	check(Costumes._sheet_textures.is_empty(),"catalog registration does not synchronously load costume sheets")
	var folder=ProjectSettings.globalize_path("res://../runtime/costume-session-v04/"+str(Time.get_ticks_usec()))
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	game.set_physics_process(false);var local=game.session;local.set_physics_process(false);local.save_directory=folder.path_join("ui");game.refresh_slot_summary()
	check(Costumes._sheet_textures.is_empty(),"game and creator setup remain lazy before opening")
	click(game.start_button);await process_frame;var panel=game.character_sheet
	check(panel.visible and not local.connected,"actual start button opens creator")
	check(Costumes._sheet_textures.is_empty(),"fixed-default creator does not load sale costumes")
	panel.name_field.text="별빛코스튬모험가";panel.name_field.text_changed.emit(panel.name_field.text)
	for cls in Creation.CLASSES:
		click(panel.job_buttons[cls]);panel.sheet.stats=Creation.suggested(cls);panel.refresh();await process_frame
		check(panel.avatar_keys==["auto"] and panel.avatar_buttons.is_empty() and not panel.avatar_grid.visible,cls+" creator has no free alternate selection")
		check(panel.sheet.avatar=="auto" and panel.sheet.costume=="none" and not panel.create_button.disabled,cls+" fixed base appearance validates")
		check(panel.portrait.sheet.class_id==cls and panel.portrait.sheet.costume=="none",cls+" preview shows class base appearance")
		label_fits(panel.appearance_label,cls+" base appearance name")
		for id in npc_ids:check(id not in panel.avatar_keys,cls+" creator excludes firearm NPC "+id)
		for id in ids:
			var sample={"name":"분류 검사","class_id":cls,"avatar":"auto","costume":id,"stats":Creation.suggested(cls)}
			check(not Creation.reason(sample).is_empty(),cls+" creation rejects unpurchased alternate appearance "+id)
		await capture("creator-base-"+cls)
	var final_sheet=panel.sheet.duplicate(true);click(panel.create_button);await process_frame;local.set_physics_process(false)
	check(local.connected and not panel.visible and game.hud.visible,"actual creator submit enters tutorial")
	var p=local.sim.players[1];check(p.costume==final_sheet.costume and p.stats==final_sheet.stats,"UI selection committed with chosen stats")
	starter_checks(p,local.sim,"UI creation")
	p.tutorial_kills=5;check(local.travel("town"),"tutorial completion permits normal town class switching");p=local.sim.players[1]
	game.toggle_bag();check(game.bag.visible and local.paused,"inventory browsing pauses gameplay")
	check(game.bag.costume_keys==["none"],"new character inventory has no unpurchased costumes")
	var registered=[]
	for index in player_ids.size():
		var id=player_ids[index];var cls=allowed_class[id]
		if p.class_id!=cls:check(local.act("class",cls),"town switches to compatible costume class "+cls);p=local.sim.players[1]
		p.pos=World.FACILITIES.shop.pos;var sale_id="costume:"+id
		check(sale_id in Wardrobe.options(cls) and id not in game.bag.costume_keys,id+" class-compatible sale is absent from inventory before purchase")
		p.gold=Wardrobe.price(sale_id)+37;var before_gold=p.gold;var before_outfit=p.costume;local.refresh()
		check(local.act("buy_appearance",sale_id),id+" public near-shop purchase action succeeds")
		check(p.gold==before_gold-Wardrobe.price(sale_id) and Wardrobe.owned(p,sale_id) and p.costume==before_outfit,id+" purchase deducts price without silent equip")
		var baseline=identity_except_costume(p,local.sim);var selected=game.bag.costume_keys.find(id)
		check(selected>=0 and game.bag.costume_keys==Wardrobe.owned_costumes(p),id+" inventory exposes only owned compatible appearances")
		game.bag.costume_picker.select(selected);game.bag.costume_picker.item_selected.emit(selected);await draw_frame();p=local.sim.players[1]
		check(p.costume==id and game.bag.costume_picker.selected==selected,id+" inventory selection reaches session")
		check(identity_except_costume(p,local.sim)==baseline,id+" costume switch preserves gear stats class skills and currency")
		check(game.bag.portrait.texture==Gat.frame(p,0.).texture and game.bag.portrait.material==Gat.material(),id+" bag consumes selected RGBA frame and shared material")
		check(game.hud.portrait.atlas==Costumes.frame(p,0.).texture.atlas and Rect2(Vector2(36,37)+game.hud.profile_offset,Vector2(72,72)).encloses(game.hud.portrait_rect()),id+" HUD consumes selected sheet with full head fit")
		registered.append(id)
		check(logical_viewport().encloses(canvas_rect(game.bag.costume_picker)),id+" selected costume control stays inside viewport")
		var picker=game.bag.costume_picker
		check(picker.get_theme_font("font").get_string_size(picker.text,HORIZONTAL_ALIGNMENT_LEFT,-1,picker.get_theme_font_size("font_size")).x<=picker.size.x-34,id+" costume name fits selected control")
		if index in [0,15,29]:
			await capture("bag-"+id);game.toggle_bag();await capture("hud-"+id);game.toggle_bag()
	check(registered==player_ids,"all thirty costumes purchased and equipped through actual inventory controls")
	game.bag.costume_picker.grab_focus();key(KEY_SPACE);await draw_frame();var popup=game.bag.costume_picker.get_popup()
	check(popup.visible,"real inventory costume popup opens")
	check(logical_viewport().encloses(Rect2(Vector2(popup.position),Vector2(popup.size))),"all-costume popup is bounded by viewport and can scroll")
	await capture("inventory-picker");popup.hide()
	var before_invalid=identity_except_costume(p,local.sim);var old_costume=p.costume
	check(not local.act("costume","missing-costume") and p.costume==old_costume and identity_except_costume(p,local.sim)==before_invalid,"unknown costume action leaves player unchanged")
	for id in npc_ids:
		check(id not in game.bag.costume_keys and not local.act("costume",id),id+" NPC costume hidden and rejected as player selection")
		check(p.costume==old_costume and identity_except_costume(p,local.sim)==before_invalid,id+" rejected NPC appearance preserves equipment and stats")
	game.toggle_bag()
	var visitors=preload("res://scripts/town_visitors.gd").RESIDENTS
	check(visitors.size()==3 and visitors.all(func(visitor):return visitor.costume in npc_ids),"all three firearm sheets have actual town visitor consumers")
	game.options.report=folder.path_join("art-usage.json")
	game.art_usage.npcs=[]
	for visitor in visitors:
		p.pos=visitor.pos+Vector2(0,2);local.refresh();game.camera_pos=preload("res://scripts/dungeon.gd").iso(visitor.pos);game.queue_redraw();await draw_frame()
		check(visitor.costume in game.art_usage.npcs and Gat.frame(visitor,0.).costume_id==visitor.costume,visitor.costume+" town renderer draws assigned original source")
		check(logical_viewport().has_point(game.world_point(visitor.pos)),visitor.costume+" visitor visible in actual camera")
		await capture("npc-"+visitor.costume)
	local.disconnect_game();game.stop_audio();root.remove_child(game);game.queue_free();await process_frame
	# Independently buy, equip, save and reload all 30 compatible costumes.
	for index in player_ids.size():
		var id=player_ids[index];var cls=allowed_class[id];var sheet={"name":"별빛코스튬모험가","class_id":cls,"avatar":"auto","costume":"none","stats":Creation.suggested(cls)};var session=Local.new();root.add_child(session);session.set_physics_process(false);session.save_directory=folder.path_join(id)
		check(session.create_character(sheet,1),id+" fresh character save succeeds")
		p=session.sim.players[1];starter_checks(p,session.sim,id)
		check(p.costume=="none" and p.avatar=="auto" and p.owned_appearances.is_empty(),id+" fresh character starts with class base only")
		p.tutorial_kills=5;check(session.travel("town"),id+" finishes tutorial before shop")
		p=session.sim.players[1];p.pos=World.FACILITIES.shop.pos;p.gold=1200
		var earned_points=Progression.available(p)
		check(p.level==2 and earned_points==3,id+" tutorial awards normal level-two stat points before costume purchase")
		check(session.act("buy_appearance","costume:"+id) and p.gold==0 and p.costume=="none",id+" shop purchase persists ownership and exact debit")
		check(session.act("wear_appearance","costume:"+id),id+" purchased costume equips in shop")
		var saved_identity=identity_except_costume(p,session.sim);var parsed=session.parse_save(session.save_path())
		check(parsed!=null and parsed.costume==id and parsed.avatar=="auto" and parsed.stats==sheet.stats and "costume:"+id in parsed.owned_appearances,id+" parser accepts purchased costume and creation data")
		check(Progression.available(p)==earned_points and p.creation_points==10,id+" costume gives no extra creation stat points")
		session.disconnect_game();session.start_game("불러오기 이름",1);p=session.sim.players[1]
		check(p.costume==id and p.avatar=="auto" and p.name==sheet.name,id+" save reload preserves appearance and name")
		check(identity_except_costume(p,session.sim)==saved_identity,id+" save reload preserves all gear progression and combat stats")
		check(Gat.frame(p,0.).costume_id==id and Gat.portrait(p)==Costumes.portrait(p),id+" loaded character still routes through custom frame and portrait")
		session.disconnect_game();root.remove_child(session);session.free()
	var invalid=final_sheet.duplicate(true);invalid.costume="missing-costume";check(not Creation.reason(invalid).is_empty() and Creation.player_data(invalid).is_empty(),"invalid creator costume never produces save data")
	var errors=logger.snapshot();check(errors.is_empty(),"no runtime parse resource or render errors")
	for error in errors:print("COSTUME_SESSION_ERROR ",error)
	print("COSTUME_SESSION_V04_TESTS checks=%d failures=%d player_costumes=%d npc_costumes=%d captures=%d render_errors=%d"%[checks,failures.size(),player_ids.size(),npc_ids.size(),captures.size(),errors.size()])
	quit(0 if failures.is_empty() else 1)
