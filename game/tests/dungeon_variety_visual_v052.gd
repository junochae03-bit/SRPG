extends SceneTree

const Sim=preload("res://scripts/simulation.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var checks=0
var failures:Array=[]
var captures:Array=[]
var maps:Array=[]
var game

class TopologyGallery extends Node2D:
	var maps:Array=[]
	var font:Font
	const NAMES={"branching":"가지 길","circuit":"순환 회랑","great_cavern":"대공동","side_hollows":"곁굴","split_bridges":"갈라진 다리","crossed_halls":"교차 성채"}
	func _draw():
		draw_rect(Rect2(0,0,1600,900),Color("14252b"))
		draw_string(font,Vector2(36,40),"자유 탐사 실제 생성 지도 · 초록 입구 / 금색 수문장 / 붉은 적",HORIZONTAL_ALIGNMENT_LEFT,1500,24,Color("edf2df"))
		for index in range(maps.size()):
			var map=maps[index];var origin=Vector2(34+(index%3)*520,74+int(index/3)*405)
			draw_string(font,origin+Vector2(0,24),"B%d · %s"%[map.floor_number,NAMES[map.layout_id]],HORIZONTAL_ALIGNMENT_LEFT,480,23,Color("f1df9a"))
			var at=origin+Vector2(68,36);var scale=320./Dungeon.SIZE
			for cell in map.floor_cells:draw_rect(Rect2(at+Vector2(cell)*scale,Vector2.ONE*(scale+.2)),Color("7f948a"))
			for record in map.encounters:draw_circle(at+(record.pos+Vector2(.5,.5))*scale,3.3 if record.role=="normal" else 5,Color("d66555"))
			draw_circle(at+(map.spawn+Vector2(.5,.5))*scale,6,Color("88efab"))
			draw_circle(at+(map.exit_position+Vector2(.5,.5))*scale,7,Color("f5d37a"))
			draw_string(font,origin+Vector2(68,384),"통로 7칸 이상 · 전투 구역 8개 · 적 23",HORIZONTAL_ALIGNMENT_LEFT,440,17,Color("c4d1ca"))

func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func capture(name:String):
	await process_frame;await RenderingServer.frame_post_draw
	var shot=root.get_texture().get_image()
	check(shot.get_size()==Vector2i(1920,1080),"FullHD "+name)
	var path="res://../artifacts/dungeon-variety-v052-"+name+".png"
	check(shot.save_png(ProjectSettings.globalize_path(path))==OK,"capture "+name)
	captures.append(ProjectSettings.globalize_path(path))

func floor_view(floor_number:int):
	var config=Abyss.config(floor_number);var local=game.session
	local.sim=Sim.new(177+floor_number*7919,config.terrain,floor_number)
	var player=local.sim.add_player(1,"던전 탐사");player.level=100;player.tutorial_done=true
	player.pos=Vector2(local.sim.map.rooms[1])
	local.refresh();game.on_entered();game.update_battle_camera(player,1.,true)
	game.visual_time=2.;game.set_process(false);game.forest.update_camera(1.);game.queue_redraw()
	check(game.dungeon==local.sim.map and game.forest.map==local.sim.map,"actual map/collision/render sharing")
	check(game.forest.props.all(func(prop):return game.forest.clear_for_prop(prop.pos)),"actual scenery clearance")
	await capture("B%d-%s"%[floor_number,local.sim.map.layout_id])
	check(game.forest.ground_evidence().draws>0,"real ground shader draws")
	if floor_number<=6:maps.append(local.sim.map)

func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/dungeon-variety-visual-v052/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false)
	for floor_number in [1,2,3,4,5,6,41,51,100]:await floor_view(floor_number)
	var layer=CanvasLayer.new();layer.layer=90;root.add_child(layer)
	var gallery=TopologyGallery.new();gallery.maps=maps;gallery.font=game.fonts;layer.add_child(gallery);gallery.queue_redraw()
	await capture("topologies")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();layer.queue_free();await process_frame;await process_frame
	print("DUNGEON_VARIETY_VISUAL_V052 checks=",checks," failures=",failures.size()," captures=",JSON.stringify(captures))
	quit(0 if failures.is_empty() else 1)
