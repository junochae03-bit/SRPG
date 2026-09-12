extends SceneTree
const Art = preload("res://scripts/gat_art.gd")
const Jobs = preload("res://scripts/job_art.gd")
const Regions = preload("res://scripts/sprite_frame_regions.gd")
var checks = 0
var failures = []
var board: Node2D
var samples = [["sniper",7],["sniper",6],["explorer",11],["elementalist",7],["hunter",15],["reaper",10]]
var rendered = []
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func run():
	Jobs.initialize(); Regions.initialize()
	var preview=preload("res://scripts/character_preview.gd").new();preview.size=Vector2(400,400)
	var hud=preload("res://scripts/combat_hud.gd").new()
	for key in Jobs.data.sprites:
		var entry = Jobs.data.sprites[key]
		hud.p={"class_id":key,"avatar":"auto","costume":"none"};hud.refresh_portrait()
		check(hud.portrait!=null and hud.portrait_rect().has_area(),"HUD idle portrait "+key)
		for index in range(16):
			var f = entry.frames[index]
			var raw = {"index":index,"texture":Jobs.texture("sprites",key,index),"foot":Vector2(f.foot[0],f.foot[1]),"height":entry.body_height}
			var fixed = Regions.apply(raw,"jobs:"+key)
			check(fixed.height==raw.height and fixed.index==index,"timing and scale "+key+str(index))
			check(fixed.texture==Regions.apply(raw,"jobs:"+key).texture,"cached geometry "+key+str(index))
			check(preview.draw_rect_for(fixed).has_area(),"preview fits geometry "+key+str(index))
			check(hud.cached_portrait_bounds(fixed.texture).has_area(),"portrait bounds "+key+str(index))
			if fixed.texture is MeshTexture:
				var top=Rect2(Vector2.ZERO,Vector2(fixed.texture.get_width(),ceilf(fixed.texture.get_height()*.62)))
				var cropped=Regions.crop(fixed.texture,top)
				check(cropped is MeshTexture and cropped.get_size().is_equal_approx(top.size),"portrait geometry crop "+key+str(index))
			var spec = Regions.entries.get("jobs:"+key,{}).get(str(index),{})
			if not spec.is_empty() and not spec.has("use_frame"):
				check((Vector2(f.rect[0],f.rect[1])+raw.foot).is_equal_approx(Vector2(spec.rect[0],spec.rect[1])+fixed.foot),"source anchor "+key+str(index))
	preview.free();hud.free()
	root.size=Vector2i(1200,2160);root.content_scale_size=root.size
	board=Node2D.new();board.material=Art.material();board.draw.connect(draw_board);root.add_child(board)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var captured=root.get_texture().get_image()
	# Pixel (1005,498) belongs to sniper's arrow in frame 6, not frame 7.
	# Verify BOTH the old contamination and recovery without relying on metadata.
	for row in [0,1]:
		var sample=rendered[row]
		var offset=Vector2(1005,498)-sample.source_anchor
		var old_pixel=captured.get_pixelv(Vector2i(sample.left+offset))
		var new_pixel=captured.get_pixelv(Vector2i(sample.right+offset))
		var background=Color("29363d")
		var old_visible=Vector3(old_pixel.r-background.r,old_pixel.g-background.g,old_pixel.b-background.b).length()>.1
		var new_visible=Vector3(new_pixel.r-background.r,new_pixel.g-background.g,new_pixel.b-background.b).length()>.1
		check(old_visible if row==0 else not old_visible,"baseline arrow error "+str(row))
		check(not new_visible if row==0 else new_visible,"GPU arrow belongs only to release "+str(row))
	var folder=ProjectSettings.globalize_path("res://../runtime/sprite-frame-regions")
	DirAccess.make_dir_recursive_absolute(folder)
	captured.save_png(folder+"/before-after.png")
	var report=FileAccess.open(folder+"/verification.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));report.close()
	print("SPRITE_FRAME_REGIONS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
func draw_board():
	board.draw_rect(Rect2(0,0,1200,2160),Color("29363d"))
	rendered.clear()
	for row in range(samples.size()):
		var key=samples[row][0];var index=samples[row][1]
		var entry=Jobs.data.sprites[key];var f=entry.frames[index]
		var raw={"index":index,"texture":Jobs.texture("sprites",key,index),"foot":Vector2(f.foot[0],f.foot[1]),"height":entry.body_height}
		var fixed=Regions.apply(raw,"jobs:"+key)
		var left=Vector2(260,row*360+330);var right=Vector2(860,row*360+330)
		for pair in [[raw,left],[fixed,right]]:
			board.draw_texture_rect(pair[0].texture,Rect2(pair[1]-pair[0].foot,pair[0].texture.get_size()),false)
		board.draw_string(ThemeDB.fallback_font,Vector2(25,row*360+24),key+" frame "+str(index)+" / BEFORE",HORIZONTAL_ALIGNMENT_LEFT,-1,20)
		board.draw_string(ThemeDB.fallback_font,Vector2(625,row*360+24),"AFTER",HORIZONTAL_ALIGNMENT_LEFT,-1,20)
		rendered.append({"left":left,"right":right,"source_anchor":Vector2(f.rect[0],f.rect[1])+raw.foot})
