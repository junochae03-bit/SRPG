extends SceneTree
const Env=preload("res://scripts/environment_art.gd")
const Art=preload("res://scripts/world_art.gd")
const Sim=preload("res://scripts/simulation.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var game
var captures=[]
class Gallery extends Node2D:
	var rows=[]
	var font:Font
	var title=""
	var columns=6
	var cell=Vector2(240,190)
	func _draw():
		draw_rect(Rect2(-80,0,1600,900),Color("edf0df"))
		draw_string(font,Vector2(20,35),title,HORIZONTAL_ALIGNMENT_LEFT,1380,22,Color("254638"))
		for i in range(rows.size()):
			var row=rows[i];var at=Vector2(0,52)+Vector2(i%columns,int(i/columns))*cell
			draw_line(at+Vector2(8,cell.y-33),at+Vector2(cell.x-8,cell.y-33),Color("b6c5ad"))
			var scale=minf((cell.x-12)/row.texture.get_width(),(cell.y-42)/row.height)
			var foot=at+Vector2(cell.x*.5,cell.y-34)
			draw_texture_rect(row.texture,Rect2(foot-row.foot*scale,row.texture.get_size()*scale),false)
			draw_string(font,at+Vector2(5,cell.y-11),row.id,HORIZONTAL_ALIGNMENT_LEFT,cell.x-10,11,Color("284938"))
func _initialize():run.call_deferred()
func capture(name:String):
	await create_timer(.18).timeout;await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	assert(image.save_png(ProjectSettings.globalize_path("res://../artifacts/"+name+".png"))==OK)
	captures.append(name);print("CAPTURE ",name)
func map_view(zone:String,floor_number:int=0,at_boss:bool=false):
	var local=game.session;local.sim=Sim.new(20260909+floor_number,zone,floor_number)
	var p=local.sim.add_player(1,"원화 통합 검사");p.level=100;p.tutorial_done=true;p.class_id="warrior"
	if at_boss:
		var bosses=local.sim.enemies.values().filter(func(e):return e.get("raid",false));assert(not bosses.is_empty())
		var boss=bosses[0];p.pos=boss.pos+Vector2(2.2,2.2);boss.attack_motion=.25
	elif floor_number>0:p.pos=Vector2(local.sim.map.rooms[3])
	local.refresh();game.on_entered();game.update_battle_camera(p,1.0,true)
	game.visual_time=2.;game.set_process(false);game.forest.update_camera(1.)
	game.queue_redraw();await capture("environment-v04-"+("boss-" if at_boss else "")+(str(floor_number) if floor_number>0 else zone))
func run():
	Env.initialize();Art.dungeon_initialize()
	game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=ProjectSettings.globalize_path("res://../runtime/environment-visual-v04/"+str(Time.get_ticks_usec()))
	game.join_game();local.set_physics_process(false);game.set_physics_process(false)
	for zone in ["forest","town"]:await map_view(zone)
	for f in [1,11,21,31,41,51,61,71,81,91]:await map_view(Abyss.config(f).terrain,f)
	for f in [30,40,50,70,90,100]:await map_view(Abyss.config(f).terrain,f,true)
	var layer=CanvasLayer.new();layer.layer=30;layer.offset=Vector2(80,0);root.add_child(layer)
	var gallery=Gallery.new();gallery.material=preload("res://scripts/gat_art.gd").material();gallery.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;gallery.font=game.fonts;layer.add_child(gallery)
	gallery.title="V0.4 108 environment props / actual atlas coordinates";gallery.columns=12;gallery.cell=Vector2(120,93)
	for id in Env.catalog.objects:
		var row=Env.frame(id);row["id"]=id;gallery.rows.append(row)
	gallery.queue_redraw();await capture("environment-v04-atlas")
	gallery.rows=[];gallery.columns=6;gallery.cell=Vector2(240,139);gallery.title="V0.4 fantasy environments / actual atlas coordinates"
	for id in Env.catalog.objects:
		if Env.catalog.objects[id].source_pack!="fantasy":continue
		var row=Env.frame(id);row["id"]=id;gallery.rows.append(row)
	gallery.queue_redraw();await capture("environment-v04-fantasy")
	gallery.rows=[];gallery.columns=6;gallery.cell=Vector2(240,139);gallery.title="V0.4 monsters / idle and attack key poses"
	for theme in Art.dungeon_catalog.themes:
		for kind in Art.dungeon_catalog.variants[theme]:
			var id=Art.dungeon_catalog.variants[theme][kind]+"_idle"
			if gallery.rows.any(func(row):return row.id==id):continue
			for attack in [false,true]:
				var row=Art.variant_frame(kind,(["forest","cave","flood","spore","lava","snow","machine","autumn","nebula","core"].find(theme))*10+1,false,attack);row["id"]=row.art_id;gallery.rows.append(row)
	gallery.queue_redraw();await capture("environment-v04-monsters")
	gallery.rows=[];gallery.columns=6;gallery.cell=Vector2(240,360);gallery.title="V0.4 bosses / idle and attack key poses"
	for f in [30,40,50,70,90,100]:
		for attack in [false,true]:
			var row=Art.variant_frame(Abyss.config(f).boss,f,true,attack);row["id"]=row.art_id;gallery.rows.append(row)
	gallery.queue_redraw();await capture("environment-v04-bosses")
	game.stop_audio();local.connected=false;game.queue_free();layer.queue_free();await process_frame;await process_frame
	print("ENVIRONMENT_VISUAL_V04_PASS captures=%d"%captures.size());quit()
