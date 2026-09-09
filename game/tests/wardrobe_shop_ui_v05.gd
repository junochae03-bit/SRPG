extends SceneTree
const Wardrobe=preload("res://scripts/wardrobe.gd")
const Names=preload("res://scripts/sprite_names.gd")
const World=preload("res://scripts/world_catalog.gd")
const Creation=preload("res://scripts/character_creation.gd")
const Gat=preload("res://scripts/gat_art.gd")
var checks=0
var failures=[]
var captures=[]
func _initialize():
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func click(control:Control):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func capture(name:String):
	await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/wardrobe-v05-"+name+".png");DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name);captures.append(path)
func rect_in_view(control:Control)->bool:
	var transform=control.get_global_transform_with_canvas()
	var bounds=Rect2(transform*Vector2.ZERO,control.size*transform.get_scale())
	var viewport=Rect2(Vector2.ZERO,Vector2(ProjectSettings.get_setting("display/window/size/viewport_width",1600),ProjectSettings.get_setting("display/window/size/viewport_height",900)))
	return viewport.encloses(bounds)
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var previous_path=Names.save_path;var previous_aliases=Names.aliases.duplicate(true)
	var folder=ProjectSettings.globalize_path("res://../runtime/wardrobe-shop-ui/"+str(Time.get_ticks_usec()))
	var game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=folder;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=folder;Names.configure(folder.path_join("sprite-names.json"))
	game.set_physics_process(false);local.set_physics_process(false)
	check(local.create_character({"name":"의상실 검사","class_id":"mage","avatar":"auto","costume":"none","stats":Creation.suggested("mage")},1),"create isolated default-appearance character")
	local.sim.players[1].tutorial_kills=5;check(local.travel("town"),"reach actual town")
	var p=local.sim.players[1];p.gold=5000;p.pos=World.resident_pos("shop");local.refresh()
	check(local.act("interact") and game.npc_dialogue.visible,"merchant speaks before shop")
	click(game.npc_dialogue.service_button);await process_frame
	var town=game.town_panel
	check(town.visible and local.paused and town.facility=="shop","existing service opens merchant with pause")
	check(town.shop_tabs.keys()==["buy","sell","costume"],"third merchant tab beside buy and sell")
	click(town.shop_tabs.costume);await process_frame
	var view=town.wardrobe_view
	check(town.shop_mode=="costume" and view!=null and town.review_panel==null,"wardrobe uses full body without generic transaction review")
	check(view.options==Wardrobe.options("mage") and view.cards.size()==4,"only compatible paged options")
	check("avatar:gat_role_aoe_1" not in view.options and view.options.count("base:mage")==1,"shop shows the free mage default once and offers no duplicate purchase")
	check(view.action_button.disabled and view.action_button.text=="착용 중","free base appearance is identified as current")
	var id=view.options.filter(func(value):return value.begins_with("costume:"))[0]
	town.wardrobe_selection=id;town.wardrobe_page=int(view.options.find(id)/view.PAGE_SIZE);town.refresh();await process_frame;view=town.wardrobe_view
	var selected_page=town.wardrobe_page
	check(view.cards.has(id) and view.action_button.text=="구매하기" and not view.action_button.disabled,"unowned costume offers explicit purchase")
	for control in [view.portrait,view.selected_name,view.name_field,view.rename_button,view.action_button,view.next_button]:check(rect_in_view(control),"visible wardrobe control bounds "+control.get_class())
	var frame=Gat.frame(view.portrait.sheet,0.)
	var drawn=view.portrait.draw_rect_for(frame);var opaque=view.portrait.opaque_rect_for(frame)
	var factor=drawn.size/frame.texture.get_size()
	check(Rect2(Vector2.ZERO,view.portrait.size).encloses(Rect2(drawn.position+opaque.position*factor,opaque.size*factor)),"full body artwork fits selected preview")
	var gold=p.gold;var ownership=p.owned_appearances.duplicate()
	view.name_field.text=" ";view.name_field.text_changed.emit(" ");check(view.rename_button.disabled,"blank name cannot be saved")
	var alias="별".repeat(24);view.name_field.text=alias;view.name_field.text_changed.emit(alias)
	check(view.name_field.max_length==24 and not view.rename_button.disabled,"24-character name is editable on unowned art")
	click(view.rename_button);await process_frame;view=town.wardrobe_view
	check(Wardrobe.label(id)==alias and view.selected_name.text==alias and view.cards[id].tooltip_text==alias,"saved alias appears on selected art and catalog")
	check(view.card_names[id].size.x<=223 and view.card_names[id].get_line_count()==2,"24-character card name wraps into fixed-width two lines")
	check(view.selected_name.size.x<=331 and view.selected_name.get_line_count()==2,"24-character detail name wraps inside frame")
	check(view.card_names[id].get_visible_line_count()==2 and view.selected_name.get_visible_line_count()==2,"both long-name lines are visible without ellipsis")
	check(view.portrait.position.y>=view.selected_name.get_rect().end.y+16,"long detail name leaves clear space above character silhouette")
	check(Rect2(Vector2(18,18),view.cards[id].size-Vector2(36,36)).encloses(view.card_names[id].get_rect()),"long card name respects ornamental inset")
	check(p.gold==gold and p.owned_appearances==ownership,"renaming unowned art does not buy or spend")
	check(town.wardrobe_selection==id and town.wardrobe_page==selected_page,"selection and page survive alias refresh")
	check(FileAccess.file_exists(Names.save_path),"alias stored separately in isolated save directory")
	await capture("unowned-name")
	var original_appearance=[p.avatar,p.costume]
	click(view.action_button);await process_frame;view=town.wardrobe_view
	check(Wardrobe.owned(p,id) and p.gold==gold-Wardrobe.price(id),"purchase button pays displayed price and grants ownership")
	check([p.avatar,p.costume]==original_appearance and view.action_button.text=="착용하기","buying does not silently equip")
	check("1200" in town.last_receipt and "1200" in view.feedback.text,"gold receipt shows actual debit")
	click(view.action_button);await process_frame;view=town.wardrobe_view
	check(view.equipped_id(p)==id and p.gold==gold-Wardrobe.price(id) and view.action_button.disabled,"owned item equips without another payment")
	town.refresh();await process_frame;view=town.wardrobe_view
	check(town.wardrobe_selection==id and town.wardrobe_page==selected_page,"selection survives purchase/equip refresh")
	await capture("owned-equipped")
	if not view.next_button.disabled:
		click(view.next_button);await process_frame;view=town.wardrobe_view
		check(town.wardrobe_page==selected_page+1 and view.cards.size()<=4,"actual next-page input changes catalog page")
		click(view.previous_button);await process_frame;view=town.wardrobe_view
		check(town.wardrobe_page==selected_page,"previous-page input restores page")
	var unowned=view.options.filter(func(value):return not Wardrobe.owned(p,value))[0]
	town.wardrobe_selection=unowned;town.wardrobe_page=int(view.options.find(unowned)/view.PAGE_SIZE);town.last_receipt="";p.gold=0;town.refresh();await process_frame;view=town.wardrobe_view
	check(view.action_button.disabled and view.feedback.text=="금화가 부족합니다.","insufficient funds visibly disable purchase")
	click(town.shop_tabs.buy);await process_frame
	check(town.shop_mode=="buy" and town.review_panel!=null and town.wardrobe_view==null,"ordinary purchase review remains available")
	click(town.shop_tabs.sell);await process_frame
	check(town.shop_mode=="sell" and town.review_panel!=null,"ordinary sale review remains available")
	town.close();check(not town.visible and not local.paused,"merchant close restores play")
	game.stop_audio();local.disconnect_game();root.remove_child(game);game.queue_free();await process_frame
	Names.save_path=previous_path;Names.aliases=previous_aliases;Names.revision+=1
	print("WARDROBE_SHOP_UI_V05_TESTS checks=",checks," failures=",failures.size()," captures=",captures.size());quit(0 if failures.is_empty() else 1)
