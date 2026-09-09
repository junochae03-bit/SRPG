extends SceneTree
const Wardrobe=preload("res://scripts/wardrobe.gd")
const Names=preload("res://scripts/sprite_names.gd")
const Content=preload("res://scripts/content.gd")
const Creation=preload("res://scripts/character_creation.gd")
const Sim=preload("res://scripts/simulation.gd")
const Local=preload("res://scripts/local_session.gd")
const World=preload("res://scripts/world_catalog.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
	Content.initialize_jobs()
	for cls in Creation.CLASSES:
		var sheet={"name":"모험가", "class_id":cls,"avatar":"auto","costume":"none","stats":Creation.suggested(cls)}
		check(Creation.reason(sheet).is_empty(),cls+" starts with class default")
		var created=Creation.player_data(sheet)
		check(created.avatar=="auto" and created.costume=="none" and created.owned_appearances.is_empty(),cls+" no free costumes at creation")
		for id in Content.costume_options(cls):
			if id=="none":continue
			sheet.costume=id;check(not Creation.reason(sheet).is_empty(),cls+" refuses creator costume "+id)
		check(Wardrobe.options(cls).all(func(id):return Wardrobe.valid_id(id)),cls+" shop uses stable valid IDs")
		var duplicate="avatar:"+Wardrobe.default_avatar_id(cls)
		check(duplicate not in Wardrobe.options(cls),cls+" free default is not sold again as an avatar")
		var buyer={"class_id":cls,"gold":5000,"owned_appearances":[]}
		check(not Wardrobe.purchase(buyer,duplicate) and buyer.gold==5000 and buyer.owned_appearances.is_empty(),cls+" duplicate default purchase cannot spend gold")
	for cls in Content.CLASSES:
		if not load("res://scripts/job_art.gd").has_sprite({"class_id":cls,"avatar":"auto","costume":"none"}):continue
		check(Wardrobe.default_avatar_id(cls)=="",cls+" distinct advanced job defaults do not hide family avatar art")
	var legacy_default={"class_id":"warrior","gold":731,"avatar":"gat_role_tank_2","costume":"none","owned_appearances":["avatar:gat_role_tank_2"]}
	Wardrobe.normalize(legacy_default,legacy_default.duplicate(true))
	check(legacy_default.owned_appearances==["avatar:gat_role_tank_2"] and legacy_default.avatar=="gat_role_tank_2" and legacy_default.gold==731,"previously owned default appearance remains intact")
	check(Wardrobe.equip(legacy_default,"base:warrior") and Wardrobe.equip(legacy_default,"avatar:gat_role_tank_2") and legacy_default.gold==731,"legacy owned duplicate can still be worn without purchase")
	var sim=Sim.new(551,"town");var p=sim.add_player(1,"구매 검사")
	var available=Wardrobe.options(p.class_id);var id=available.filter(func(value):return value.begins_with("costume:"))[0]
	p.pos=World.FACILITIES.shop.pos;p.gold=Wardrobe.price(id)-1
	var before=sim.persistent(1).duplicate(true)
	check(not sim.action(1,"buy_appearance",id) and sim.persistent(1)==before,"insufficient gold changes nothing")
	check(not sim.action(1,"costume",id.get_slice(":",1)),"unowned costume cannot be equipped directly")
	p.gold=2400;var property=p.inventory.duplicate(true)
	check(sim.action(1,"buy_appearance",id) and p.gold==2400-Wardrobe.price(id),"purchase deducts exact gold")
	check(Wardrobe.owned(p,id) and p.inventory==property,"appearance ownership uses no inventory cells")
	before=sim.persistent(1).duplicate(true)
	check(not sim.action(1,"buy_appearance",id) and sim.persistent(1)==before,"duplicate purchase does not charge")
	check(sim.action(1,"wear_appearance",id) and p.costume==id.get_slice(":",1),"owned purchase can be worn at counter")
	check(sim.action(1,"costume","none") and sim.action(1,"costume",id.get_slice(":",1)),"bag switches among owned and default")
	var another=available.filter(func(value):return not Wardrobe.owned(p,value))[0]
	p.pos=sim.map.spawn
	check(not sim.action(1,"buy_appearance",another),"cannot buy away from merchant")
	check(not Wardrobe.purchase(p,"costume:missing") and not Wardrobe.equip(p,"costume:missing"),"unknown identity rejected")
	var old=sim.persistent(1).duplicate(true);old.erase("owned_appearances")
	var restored=sim.add_player(2,"기존 모험가",old)
	check(restored.costume==p.costume and Wardrobe.owned(restored,id) and restored.gold==p.gold,"legacy equipped costume and property retained without a charge")
	var unpaid=sim.persistent(1).duplicate(true);unpaid.owned_appearances=[]
	var repaired=sim.add_player(3,"미소유 기록",unpaid)
	check(repaired.costume=="none" and repaired.owned_appearances.is_empty() and repaired.gold==unpaid.gold,"new ownership field cannot grant an unpaid equipped costume")
	var folder=ProjectSettings.globalize_path("res://../runtime/wardrobe-v05/"+str(Time.get_ticks_usec()))
	var session=Local.new();root.add_child(session);session.set_physics_process(false);session.save_directory=folder
	check(session.enter_saved(sim.persistent(1),"저장 검사"),"owned appearance writes through session")
	var saved=session.parse_save(session.save_path())
	check(saved!=null and id in saved.owned_appearances,"save parser retains ownership")
	session.disconnect_game();session.start_game("재시작",1)
	check(Wardrobe.owned(session.sim.players[1],id) and session.sim.players[1].costume==p.costume,"ownership and outfit survive restart")
	session.disconnect_game();root.remove_child(session);session.free()
	Names.configure(folder.path_join("sprite-names.json"))
	check(Names.rename(id,"나의 여행 의상") and Wardrobe.label(id)=="나의 여행 의상","user can rename costume display name")
	check(not Names.rename(id,"") and not Names.rename(id,"줄\n바꿈"),"invalid names do not replace alias")
	Names.configure(folder.path_join("sprite-names.json"))
	check(Wardrobe.label(id)=="나의 여행 의상" and Wardrobe.valid_id(id),"alias survives reload and stable asset ID is unchanged")
	check(Names.rename("base:warrior","나의 검사") and Wardrobe.label("base:warrior")=="나의 검사" and Content.CLASSES.warrior.name=="검사","sprite name does not rename the class")
	Names.configure("")
	print("WARDROBE_V05_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
