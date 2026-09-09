extends SceneTree
const Art = preload("res://scripts/costume_art_v04.gd")
var captures: Array = []
var failed: Array = []

class ReviewCanvas extends Node2D:
	var costume_id: String
	var frames: Array = []
	func _draw():
		draw_rect(Rect2(0,0,2020,540),Color("dce6da"))
		var font=ThemeDB.fallback_font
		draw_string(font,Vector2(20,30),costume_id+" / ACTUAL V0.4 READER / 112px",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("173c35"))
		draw_string(font,Vector2(20,54),"Memory RGBA + existing global shader. Red = calibrated support-foot anchor. Pose body scales are normalized.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("345e50"))
		# Paint every card first so the next background never covers pose artwork.
		for i in frames.size():
			var cx=20+(i%8)*250
			var cy=76+int(i/8)*224
			draw_rect(Rect2(cx,cy,242,210),Color("c0d3bd"))
		for i in frames.size():
			var f:Dictionary=frames[i]
			var x=20+(i%8)*250
			var y=76+int(i/8)*224
			var base=Vector2(x+96,y+168)
			draw_line(base+Vector2(-80,0),base+Vector2(80,0),Color("649583"))
			var scale=112.0/float(f.height)
			draw_set_transform(base)
			draw_texture_rect(f.texture,Rect2(-f.foot*scale,f.texture.get_size()*scale),false)
			draw_set_transform(Vector2.ZERO)
			draw_line(base-Vector2(4,0),base+Vector2(4,0),Color("d73832"),1)
			draw_line(base-Vector2(0,4),base+Vector2(0,4),Color("d73832"),1)
			draw_string(font,Vector2(x+5,y+190),str(i)+" "+str(f.action),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("1d4035"))
			draw_string(font,Vector2(x+5,y+205),"body "+str(f.height)+" / foot "+str(f.foot),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("426455"))

func _initialize():
	run.call_deferred()

func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var output=ProjectSettings.globalize_path("res://../runtime/costume-v04-review")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new()
	viewport.size=Vector2i(2020,540)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas=ReviewCanvas.new()
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material=ShaderMaterial.new()
	material.shader=load("res://shaders/gat_chroma.gdshader")
	canvas.material=material
	viewport.add_child(canvas)
	for id in Art.ids():
		canvas.costume_id=id
		canvas.frames=[]
		for i in 16:
			var frame=Art._frame_at(id,i)
			if frame.is_empty(): failed.append(id+":"+str(i))
			canvas.frames.append(frame)
		if not failed.is_empty(): break
		canvas.queue_redraw()
		for j in 3: await process_frame
		await RenderingServer.frame_post_draw
		var image=viewport.get_texture().get_image()
		var path=output.path_join(id+".png")
		var err=image.save_png(path)
		if err!=OK: failed.append(path)
		captures.append({"id":id,"path":path,"frames":16,"size":[image.get_width(),image.get_height()],"error":err})
		print("COSTUME_CAPTURE ",id)
	var result={"reader":"res://scripts/costume_art_v04.gd","uses_current_global_shader":true,"target_body_px":112,"captures":captures,"failures":failed,"frames":captures.size()*16,"source_raster_changes":false}
	var f=FileAccess.open(output.path_join("render-results.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	print("COSTUME_RENDER_V04 frames=",captures.size()*16," failures=",failed.size())
	Art.reset_cache()
	quit(0 if failed.is_empty() and captures.size()==33 else 1)
