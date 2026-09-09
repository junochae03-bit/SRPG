extends SceneTree
const World=preload("res://scripts/world_catalog.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Icons=preload("res://scripts/icon_library.gd")
var checks=0
var failures:Array=[]
var captures:Array=[]
var game
var panel
var local
var p:Dictionary

func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func open_service(key:String):
	panel.close();p.pos=World.FACILITIES[key].pos;local.refresh();panel.open(key)
	check(panel.visible and local.paused and panel.size==Vector2(1560,852),"full workbench and paused game "+key)
	check(panel.counter.size.x<=220 and panel.body.size.x>=1200,"space assigned to work instead of oversized static art")
	if key=="costume":check(panel.wardrobe_view!=null and panel.review_panel==null,"dedicated boutique owns its purchase review")
	else:check(panel.preview.has("result") and panel.confirm_button!=null,"explicit selected operation quote "+key)
	if World.RESIDENTS.has(key):check(panel.greeting.text.contains(World.RESIDENTS[key].name),"resident identity "+key)

func audit_screen(label:String):
	if panel.review_panel!=null:
		var safe=Rect2(Vector2(32,26),panel.review_panel.size-Vector2(64,52))
		for child in panel.review_panel.get_children():
			if child is Label and not child.text.is_empty():check(safe.encloses(child.get_rect()),"review label remains inside paper "+label)
		check(safe.encloses(panel.confirm_button.get_rect()) and safe.encloses(panel.review_result_scroll.get_rect()),"action/result bounds "+label)
		check(panel.review_result_scroll.get_rect().end.y+12<=panel.review_labels.feedback.position.y,"result cannot cover receipt "+label)
		check(panel.review_labels.feedback.get_rect().end.y+12<=panel.confirm_button.position.y,"receipt cannot cover action "+label)
		check(panel.review_labels.name.get_rect().end.y+10<=panel.review_labels.price.position.y,"item name cannot cover price "+label)
	for text in panel.find_children("*","Label",true,false):
		if not text.is_visible_in_tree() or text.text.is_empty():continue
		var count=text.get_line_count();var intended=count if text.max_lines_visible<0 else mini(count,text.max_lines_visible)
		var needed=intended*text.get_line_height()+maxi(0,intended-1)*text.get_theme_constant("line_spacing")
		check(needed<=text.size.y+1,"allocated line height "+label+" / "+text.text)
		if text.max_lines_visible>0 and count>text.max_lines_visible:check(text.tooltip_text==text.text and text.clip_contents,"full long name available "+label)
		check(text.get_visible_line_count()>=intended,"text lines visible "+label+" / "+text.text)
	for button in panel.find_children("*","Button",true,false):
		if not button.is_visible_in_tree() or button.text.is_empty():continue
		var style=button.get_theme_stylebox("normal");var font_size=button.get_theme_font_size("font_size")
		var width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var icon=button.get_theme_constant("icon_max_width")+8 if button.icon!=null else 0
		check(width+icon<=button.size.x-style.content_margin_left-style.content_margin_right+1,"caption fits button "+label+" / "+button.text)

func capture(name:String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	audit_screen(name)
	var image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1920,1080),"actual FullHD "+name)
	var path=ProjectSettings.globalize_path("res://../artifacts/town-v052-"+name+".png")
	check(image.save_png(path)==OK,"capture "+name);captures.append(path)

func click_confirm()->bool:
	var ready=not panel.confirm_button.disabled
	panel.confirm_button.pressed.emit()
	return ready and panel.receipt_success

func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/town-clarity-v052/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();local=game.session
	local.sim.players[1].tutorial_done=true;local.travel("town");local.set_physics_process(false);game.set_physics_process(false)
	p=local.sim.players[1];p.level=100;p.gold=100000;p.materials={"seed":500,"ore":500,"essence":500};p.potions=1
	Inventory.initialize(p);local.sim.gear_changed(p)
	for index in range(12):
		var item=Equipment.make("sword",8,3 if index==0 else 1,"clarity-gear-%d"%index,"none",p.class_id)
		if index==0:item.name="찬란하게 빛나는 별빛의 전설적인 수호기사 대검";item.upgrade=4
		check(Inventory.add_gear(p,item),"test gear supplied")
	panel=game.town_panel
	open_service("shop");panel.choose("potion")
	panel.quantity_buttons[10].pressed.emit();check(panel.quantity==10 and panel.extra().quantity==10 and panel.preview.cost==150,"actual quantity buttons scale quote")
	var gold=p.gold;var potions=p.potions
	check(click_confirm() and p.gold==gold-150 and p.potions==potions+10,"UI buys selected ten potions")
	await capture("shop-quantity-receipt")
	panel.choose("buy",{"index":0});check(panel.quantity==1,"changing operation resets bulk quantity")
	panel.select_shop_mode("sell");panel.choose("sell",{"item":"clarity-gear-1"})
	check(click_confirm() and panel.selected_item=="" and panel.confirm_button.disabled,"sale requires fresh item selection")
	check(panel.review_labels.feedback.text==panel.last_receipt and panel.last_receipt.contains("완료"),"sale receipt survives now-invalid quote")
	await capture("shop-sold")
	open_service("smith");panel.choose("upgrade",{"item":"clarity-gear-0"})
	check(panel.products["clarity-gear-0"].get_meta("selected"),"selected equipment marked")
	await capture("smith-before")
	check(click_confirm() and Inventory.find_item(p,"clarity-gear-0").upgrade==5,"actual upgrade")
	check(panel.confirm_button.disabled and panel.review_labels.feedback.text==panel.last_receipt,"max upgrade does not hide success receipt")
	await capture("smith-max-receipt")
	panel.choose("salvage");check(panel.selected_item=="" and panel.confirm_button.disabled,"switching to dismantle requires explicit item")
	panel.choose("salvage",{"item":"clarity-gear-2"});var ore=p.materials.ore
	await capture("smith-salvage")
	check(click_confirm() and Inventory.find_item(p,"clarity-gear-2").is_empty() and p.materials.ore>ore,"actual salvage outputs")
	check(panel.selected_item=="" and panel.confirm_button.disabled and panel.review_labels.feedback.text==panel.last_receipt,"salvage cannot chain into next gear")
	open_service("alchemy");panel.choose("ore");panel.quantity_buttons[3].pressed.emit();ore=p.materials.ore
	await capture("alchemy-ore")
	check(click_confirm() and p.materials.ore==ore+9,"three ore recipes from quantity selector")
	panel.choose("essence");check(panel.quantity==1,"recipe change resets quantity")
	open_service("guild");panel.choose("supply");panel.refresh();check(panel.operation=="supply" and panel.preview.cost==-300,"refresh keeps selected supply operation")
	await capture("guild-supply")
	gold=p.gold;check(click_confirm() and p.gold==gold+300,"actual guild supply purchase")
	panel.choose("accept",{"zone":"cave"});check(click_confirm() and not p.guild_contract.is_empty(),"contract accepted")
	panel.choose("supply");panel.refresh();check(panel.operation=="supply","active contract does not override supply selection")
	panel.choose("cancel");check(not p.guild_contract.is_empty(),"choosing cancellation only previews")
	await capture("guild-cancel")
	check(click_confirm() and p.guild_contract.is_empty(),"explicit contract cancellation")
	open_service("inn");p.hp=35;p.stamina=4;p.potions=2;Inventory.initialize(p);panel.choose("resupply")
	await capture("inn-resupply")
	check(click_confirm() and p.hp==p.max_hp and p.stamina==p.max_stamina and p.potions==20,"inn heals and resupplies")
	open_service("portal");p.highest_floor=100;panel.chapter=9;panel.selected_floor=100;panel.refresh()
	check(panel.products.size()==10,"ten readable floors per chapter")
	await capture("portal-raid")
	open_service("costume")
	var wardrobe=preload("res://scripts/wardrobe.gd")
	var offers=wardrobe.options(p.class_id).filter(func(id):return not wardrobe.owned(p,id))
	check(not offers.is_empty(),"boutique has class-compatible outfits")
	if not offers.is_empty():
		var selected=offers[0];panel.wardrobe_view.choose(selected)
		check(panel.wardrobe_view.transact("buy_appearance") and wardrobe.owned(p,selected),"dedicated NPC purchases through existing ownership model")
		check(panel.wardrobe_view.transact("wear_appearance"),"dedicated NPC equips purchased appearance")
	await capture("costume-boutique")
	open_service("training")
	p.training_stats=preload("res://scripts/training_ground.gd").blank()
	p.training_stats.merge({"total_damage":4321,"hits":3,"criticals":1,"first_hit":1.,"last_hit":4.,"last_skill":"별빛 파동"},true);panel.refresh()
	check(panel.review_labels.price.text.contains("4321") and panel.review_labels.balance.text.contains("1440.3") and panel.review_labels.result.text.contains("별빛 파동"),"training statistics are readable actual model values")
	await capture("training-record")
	gold=p.gold;var hp=p.hp;panel.confirm_button.pressed.emit()
	check(p.training_stats.hits==0 and panel.receipt_success and p.gold==gold and p.hp==hp,"paused training menu resets practice without charging or healing")
	check(local.sim.map.in_town(World.FACILITIES.portal.pos) and not local.sim.map.in_town(World.FACILITIES.training.pos),"dungeon entrance stays outside practice area")
	check(Icons.unknown_requests.is_empty(),"new actions use registered icons")
	panel.close();check(not local.paused,"closing service resumes game")
	check(await game.audio_director.shutdown(),"audio drained")
	local.connected=false;game.queue_free();game=null;await process_frame;await process_frame
	print("TOWN_CLARITY_UI_V052 checks=",checks," failures=",failures.size()," captures=",JSON.stringify(captures))
	quit(0 if failures.is_empty() else 1)
