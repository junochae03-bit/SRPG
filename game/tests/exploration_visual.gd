extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
var game
var checks=0
var failures=[]
var captures=[]
class Gallery extends Node2D:
	var maps=[]
	var font:Font
	func _draw():
		draw_rect(Rect2(0,0,1920,1080),Color("17292e"))
		draw_string(font,Vector2(45,48),"자유 탐사 던전 · 실제 생성 지도",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("f2e8c8"))
		draw_string(font,Vector2(1030,46),"초록: 입구   금색: 수문장   파랑: 탐사방",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("cad9d1"))
		for index in range(maps.size()):
			var map=maps[index];var origin=Vector2(35+(index%3)*635,90+int(index/3)*326)
			var name=Dungeon.RAID_LAYOUTS[map.layout_id].name if map.raid_arena else Dungeon.LAYOUTS[map.layout_id].name
			draw_string(font,origin,"B%d · %s"%[map.floor_number,name],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f1df9a"))
			var at=origin+Vector2(166,12);var scale=270./float(Dungeon.RAID_SIZE if map.raid_arena else Dungeon.SIZE)
			for cell in map.floor_cells:draw_rect(Rect2(at+Vector2(cell)*scale,Vector2.ONE*(scale+.1)),Color("84968d"))
			for record in map.encounters:draw_circle(at+record.pos*scale,2.2 if record.role=="normal" else 4.,Color("e99779"))
			for site in map.exploration_sites:draw_circle(at+site.pos*scale,5,Color("73d0e1"))
			draw_circle(at+map.spawn*scale,6,Color("8aebaa"));draw_circle(at+map.exit_position*scale,6,Color("f5cd70"))
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name):
	await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1920,1080),"1080p "+name)
	var path=ProjectSettings.globalize_path("res://../artifacts/exploration-"+name+".png")
	check(image.save_png(path)==OK,"capture "+name);captures.append(path)
func scene(floor_number:int,site_index:int=-1,zone_override:String=""):
	var config=Abyss.config(floor_number);var session=game.session
	session.sim=Sim.new(571+floor_number*7919,config.terrain if zone_override.is_empty() else zone_override,floor_number)
	var p=session.sim.add_player(1,"던전 탐사");p.level=100;p.tutorial_done=true
	if site_index>=0:
		for enemy in session.sim.enemies.values():enemy.hp=0
		p.pos=session.sim.map.exploration_sites[site_index].pos+Vector2(0,1);p.hp=33
	else:p.pos=session.sim.map.exit_position+Vector2(0,6)
	session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.);game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame
	if site_index>=0:
		check(game.exploration_panel.visible,"nearby actionable card")
		var card=game.exploration_panel
		for label in [card.heading,card.detail]:check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"card text fits "+label.text)
		check(not game.session.paused,"nonmodal event preserves real time")
		check(not game.visible_world_labels.has(card.heading.text),"facility title is not duplicated over character name")
		if site_index==0:
			check(card.heading.text==("별씨앗 군락" if session.sim.map.zone=="forest" else "반짝 광맥"),"same room id and tier changes visible material between maps")
	await capture("B%d-%s%s"%[floor_number,"site%d"%site_index if site_index>=0 else "raid",zone_override])
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/exploration-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	await scene(12,0,"forest");await scene(12,0);await scene(12,1);await scene(12,2);await scene(10);await scene(20);await scene(30)
	var layer=CanvasLayer.new();layer.layer=90;root.add_child(layer)
	var gallery=Gallery.new();gallery.font=game.fonts;gallery.scale=Vector2(1600./1920.,900./1080.)
	for depth in [1,2,3,4,5,6,10,20,30]:gallery.maps.append(Dungeon.new(571+depth*7919,"cave",depth))
	layer.add_child(gallery);await capture("maps")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();layer.queue_free();await process_frame;await process_frame
	print("EXPLORATION_VISUAL checks=%d failures=%d captures=%s"%[checks,failures.size(),JSON.stringify(captures)])
	quit(0 if failures.is_empty() else 1)
