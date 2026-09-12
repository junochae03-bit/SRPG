extends SceneTree
const Art=preload("res://scripts/gat_art.gd")
const Content=preload("res://scripts/content.gd")
const Costume=preload("res://scripts/costume_art_v04.gd")
var entries=[]
var page=0
var phase=0
var board:Node2D
func _initialize():run.call_deferred()
func run():
	Content.initialize_jobs()
	for key in Content.CLASSES:entries.append({"id":"job:"+key,"class_id":key,"avatar":"auto","costume":"none"})
	for key in Content.AVATARS:entries.append({"id":key,"class_id":"ranger","avatar":key,"costume":"none"})
	for key in Costume.ids():entries.append({"id":key,"class_id":"ranger","avatar":"auto","costume":key})
	root.content_scale_size=Vector2i(1440,1000);root.size=Vector2i(1440,1000)
	board=Node2D.new();board.material=Art.material();board.draw.connect(draw_board);root.add_child(board)
	var folder=ProjectSettings.globalize_path("res://../runtime/character-runtime-gallery")
	DirAccess.make_dir_recursive_absolute(folder)
	for state in range(4):
		phase=state
		for i in range(ceili(entries.size()/24.)):
			page=i;board.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/phase-%d-page-%02d.png"%[phase,page])
	print("CHARACTER_RUNTIME_GALLERY entries=",entries.size()," output=",folder);quit()
func draw_board():
	board.draw_rect(Rect2(0,0,1440,1000),Color("29363d"))
	for j in range(24):
		var n=page*24+j
		if n>=entries.size():break
		var p=entries[n].duplicate();p.motion="shoot_high" if phase==2 else "shoot";p.motion_duration=.46;p.motion_time=p.motion_duration*(.1 if phase==1 else .48)
		if phase==3:p.motion_time=0.
		var center=Vector2(120+(j%6)*240,200+int(j/6)*245)
		board.draw_line(center-Vector2(115,0),center+Vector2(115,0),Color("54717d"))
		for side in [-1,1]:
			p.aim=Vector2(side,-side).normalized()
			var data=Art.frame(p,0);var scale=112./float(data.height)
			var at=center+Vector2(side*55,0)
			var pose=preload("res://scripts/character_presentation.gd").pose(p)
			if data.animated:pose.scale=Vector2.ONE;pose.angle*=.35
			board.draw_set_transform(at+pose.offset,pose.angle,pose.scale*Vector2(side*data.source_facing,1))
			board.draw_texture_rect(data.texture,Rect2(-data.foot*scale,data.texture.get_size()*scale),false)
			board.draw_set_transform(Vector2.ZERO)
			if phase in [0,2]:
				var muzzle=at+Art.launch_offset(p,p.aim)
				board.draw_arc(muzzle,4,0,TAU,16,Color("ffeb62"),1.5)
				board.draw_line(muzzle,muzzle+Vector2(side*12,0),Color("ffeb62"),1.5)
		board.draw_string(ThemeDB.fallback_font,center+Vector2(-115,24),p.id,HORIZONTAL_ALIGNMENT_LEFT,235,13)
