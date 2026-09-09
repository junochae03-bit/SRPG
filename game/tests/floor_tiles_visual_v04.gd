extends SceneTree
const Tiles=preload("res://scripts/floor_tile_art_v04.gd")
const Sim=preload("res://scripts/simulation.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var checks=0
var failures=[]
var game
var captures=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func capture(name:String):
	await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1920,1080),"actual FullHD "+name)
	var path=ProjectSettings.globalize_path("res://../artifacts/floor-tiles-v04-"+name+".png")
	check(image.save_png(path)==OK,"save "+name);captures.append(path)
	return image
func map_view(f:int,zoom:float=1.0,entry:bool=false):
	var local=game.session;local.sim=Sim.new(20260909+f,Abyss.config(f).terrain,f)
	var p=local.sim.add_player(1,"바닥 타일 검사");p.level=100;p.tutorial_done=true;p.class_id="warrior"
	if not entry:p.pos=Vector2(local.sim.map.rooms[1])
	local.refresh();game.on_entered();game.update_battle_camera(p,1.,true)
	game.visual_time=2.;game.set_process(false)
	if zoom!=1.0:
		var anchor=game.screen_center();root.canvas_transform=Transform2D(Vector2(zoom,0),Vector2(0,zoom),anchor*(1.0-zoom))
	game.forest.update_camera(1.);game.queue_redraw()
	var name=str(f)+("-entry" if entry else "-zoom" if zoom!=1. else "")
	await capture(name)
	var evidence=game.forest.ground_evidence()
	check(evidence.draws>0 and evidence.profile==Tiles.profile(local.sim.map.zone,f).id,"actual ground draw "+name)
	check(evidence.atlas==Tiles.catalog().atlas and not evidence.fallback,"actual atlas consumer "+name)
	check(local.sim.map.walkable(p.pos),"rendered player stands on valid floor "+name)
	root.canvas_transform=Transform2D.IDENTITY
func run():
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/floor-tiles-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false)
	for f in [1,11,21,31,41,51,61,71,81,91]:await map_view(f)
	for f in [1,61,91]:await map_view(f,1.6)
	await map_view(1,1.,true)
	# Isolated real GPU material probe: exact repeat, frame stability, material
	# variation, atlas-panel bleed/chroma and viewport coverage at shader level.
	var view=SubViewport.new();view.size=Vector2i(240,160);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var probe=ColorRect.new();probe.size=Vector2(240,160)
	var mat=ShaderMaterial.new();mat.shader=load("res://shaders/forest_ground.gdshader");probe.material=mat;view.add_child(probe)
	var mask=Image.create(64,64,false,Image.FORMAT_R8);mask.fill(Color.WHITE)
	mat.set_shader_parameter("walk_mask",ImageTexture.create_from_image(mask));mat.set_shader_parameter("terrain_extent",probe.size)
	mat.set_shader_parameter("terrain_origin",Vector2.ZERO);mat.set_shader_parameter("screen_anchor",Vector2.ZERO)
	var hashes={}
	for f in [1,11,21,31,41,51,61,71,81,91]:
		Tiles.apply(mat,Abyss.config(f).terrain,f);mat.set_shader_parameter("camera",Vector2.ZERO)
		await process_frame;await RenderingServer.frame_post_draw
		var first=view.get_texture().get_image();var bytes=first.get_data();hashes[hash(bytes)]=true
		await process_frame;await RenderingServer.frame_post_draw
		check(view.get_texture().get_image().get_data()==bytes,"no time shimmer B%d"%f)
		mat.set_shader_parameter("camera",Dungeon.iso(Vector2(10,10)))
		await process_frame;await RenderingServer.frame_post_draw
		var repeat=view.get_texture().get_image();var max_diff=0.;var chroma=0;var colors={}
		for x in range(2,238,3):
			for y in range(2,158,3):
				var a=first.get_pixel(x,y);var b=repeat.get_pixel(x,y)
				max_diff=maxf(max_diff,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
				if (a.r>.98 and a.g<.02 and a.b>.98) or (a.r<.02 and a.g<.02 and a.b>.98):chroma+=1
				colors[a.to_rgba32()]=true
		check(max_diff<.015,"GPU seamless repeat B%d max %.5f"%[f,max_diff])
		check(chroma==0 and colors.size()>200,"no chroma/fallback and real texture detail B%d"%f)
	check(hashes.size()>=8,"biome paths have distinct rendered materials/tints")
	view.queue_free()
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();game=null;await process_frame;await process_frame
	print("FLOOR_TILES_VISUAL_V04 checks=",checks," failures=",failures.size()," captures=",captures.size())
	quit(0 if failures.is_empty() else 1)
